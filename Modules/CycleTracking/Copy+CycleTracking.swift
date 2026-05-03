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

        // MARK: - Tracker Phase Display Names

        static let trackerMenstrualDisplay = "Menstrual"
        static let trackerFollicularDisplay = "Follicular"
        static let trackerOvulationDisplay = "Ovulation"
        static let trackerLutealDisplay = "Luteal"

        // MARK: - Tracker Phase Descriptions

        static let trackerMenstrualDescription = "Energy and recovery capacity are typically at their lowest. The body is shedding the uterine lining, and iron levels may dip. Fatigue and mild discomfort are common."
        static let trackerFollicularDescription = "Rising estrogen boosts energy, mood, and recovery speed. This phase favors learning new skills and building strength as the body ramps toward peak performance."
        static let trackerOvulationDescription = "Peak estrogen and a surge in luteinizing hormone drive the highest energy and performance potential of the cycle. Reaction time and power output tend to peak."
        static let trackerLutealDescription = "Progesterone rises while estrogen declines. Core temperature increases slightly, recovery slows, and energy gradually tapers toward the end of the phase."

        // MARK: - Tracker Exercise Recommendations

        static let trackerMenstrualExercise = "Favor light movement. walking, gentle yoga, or stretching. Avoid heavy lifts or high-impact sessions if energy is low."
        static let trackerFollicularExercise = "Great time to push intensity. Try heavy strength training, HIIT, or learning new movement patterns. Recovery is fast."
        static let trackerOvulationExercise = "Peak performance window. Go for PRs, high-intensity intervals, or competitive efforts. Stay mindful of joint laxity from elevated relaxin."
        static let trackerLutealExercise = "Moderate steady-state cardio and maintenance-level strength work. Reduce volume in the late luteal phase as fatigue builds."

        // MARK: - Tracker Sleep Impact

        static let trackerMenstrualSleep = "Sleep may be disrupted by cramps or discomfort in the first days. Prioritize earlier bedtimes and a cool sleep environment."
        static let trackerFollicularSleep = "Sleep quality typically improves as estrogen rises. This is often the easiest phase for consistent, restorative sleep."
        static let trackerOvulationSleep = "Sleep remains generally good, though some experience lighter sleep around the LH surge. Maintain consistent sleep timing."
        static let trackerLutealSleep = "Rising progesterone raises core temperature, which can reduce deep sleep. Expect more fragmented sleep in the late luteal phase."

        // MARK: - Tracker Nutrition Tips

        static let trackerMenstrualNutrition = "Focus on iron-rich foods (red meat, spinach, lentils) to offset menstrual losses. Anti-inflammatory foods like fatty fish and ginger can ease discomfort."
        static let trackerFollicularNutrition = "Support rising estrogen with cruciferous vegetables and lean protein. Carbohydrate tolerance is higher. A good window for complex carbs around workouts."
        static let trackerOvulationNutrition = "Maintain balanced macros with emphasis on antioxidants and fiber. Hydration is important as energy expenditure peaks."
        static let trackerLutealNutrition = "Cravings for carbs and fats are common due to increased caloric needs (~100-300 kcal/day more). Choose whole grains, magnesium-rich foods, and healthy fats."

        // MARK: - Tracker Recovery Impact

        static let trackerNoCycleData = "No cycle data available to assess recovery impact."
        static let trackerMenstrualRecoveryImpact = "Recovery is slower during menstruation. Allow extra rest between intense sessions and monitor HRV for readiness."
        static let trackerFollicularRecoveryImpact = "Recovery is at its fastest. The body adapts well to training stimulus. shorter rest periods are feasible."
        static let trackerOvulationRecoveryImpact = "Recovery remains strong but joint laxity may increase injury risk. Warm up thoroughly and prioritize form."
        static let trackerLutealRecoveryImpact = "Recovery slows as progesterone rises and core temperature climbs. Expect longer HRV recovery and higher resting heart rate."

        static let trackerNoCycleExerciseFallback = "Track at least one menstrual period to receive phase-specific training advice."
    }
}
