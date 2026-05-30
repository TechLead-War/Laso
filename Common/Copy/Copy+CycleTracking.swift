import Foundation

extension Copy {
    enum CycleTracking {

        // MARK: - Navigation

        static var title: String { RemoteConfigManager.shared.copyString("copy_cycle_tracking_cycle_tracking_title", default: "Cycle Tracking") }

        // MARK: - Phase Names

        static var menstrualPhase: String { RemoteConfigManager.shared.copyString("copy_cycle_tracking_cycle_tracking_menstrual_phase", default: "Menstrual Phase") }
        static var follicularPhase: String { RemoteConfigManager.shared.copyString("copy_cycle_tracking_cycle_tracking_follicular_phase", default: "Follicular Phase") }
        static var ovulatoryPhase: String { RemoteConfigManager.shared.copyString("copy_cycle_tracking_cycle_tracking_ovulatory_phase", default: "Ovulatory Phase") }
        static var lutealPhase: String { RemoteConfigManager.shared.copyString("copy_cycle_tracking_cycle_tracking_luteal_phase", default: "Luteal Phase") }

        // MARK: - Phase Descriptions

        static var menstrualDescription: String { RemoteConfigManager.shared.copyString("copy_cycle_tracking_cycle_tracking_menstrual_description", default: "Your period is here. Hormone levels are at their lowest, so your energy and mood may dip.") }
        static var follicularDescription: String { RemoteConfigManager.shared.copyString("copy_cycle_tracking_cycle_tracking_follicular_description", default: "Your body is gearing up after your period. Energy and mood usually start to pick up.") }
        static var ovulatoryDescription: String { RemoteConfigManager.shared.copyString("copy_cycle_tracking_cycle_tracking_ovulatory_description", default: "This is your peak window. Energy, confidence, and strength are often at their highest.") }
        static var lutealDescription: String { RemoteConfigManager.shared.copyString("copy_cycle_tracking_cycle_tracking_luteal_description", default: "Your body is winding down toward the next cycle. You may notice changes in appetite, sleep, and mood.") }

        // MARK: - Energy Impact

        static var menstrualEnergy: String { RemoteConfigManager.shared.copyString("copy_cycle_tracking_cycle_tracking_menstrual_energy", default: "Energy tends to be lower. Light movement can help, but rest when your body asks for it.") }
        static var follicularEnergy: String { RemoteConfigManager.shared.copyString("copy_cycle_tracking_cycle_tracking_follicular_energy", default: "Energy and endurance are rising. Great time for tough workouts and learning new things.") }
        static var ovulatoryEnergy: String { RemoteConfigManager.shared.copyString("copy_cycle_tracking_cycle_tracking_ovulatory_energy", default: "Peak energy and strength. You may hit personal bests during this window.") }
        static var lutealEnergy: String { RemoteConfigManager.shared.copyString("copy_cycle_tracking_cycle_tracking_luteal_energy", default: "Energy starts to wind down, especially toward the end. Shift to moderate, steady activities.") }

        // MARK: - Recovery Impact

        static var menstrualRecovery: String { RemoteConfigManager.shared.copyString("copy_cycle_tracking_cycle_tracking_menstrual_recovery", default: "Recovery may be slower right now. Focus on sleep, water, and gentle movement like yoga or walking.") }
        static var follicularRecovery: String { RemoteConfigManager.shared.copyString("copy_cycle_tracking_cycle_tracking_follicular_recovery", default: "Recovery is usually fast right now. Your body handles training well and bounces back quickly.") }
        static var ovulatoryRecovery: String { RemoteConfigManager.shared.copyString("copy_cycle_tracking_cycle_tracking_ovulatory_recovery", default: "Recovery is good, but watch your intensity. Your body may hide tiredness during this peak.") }
        static var lutealRecovery: String { RemoteConfigManager.shared.copyString("copy_cycle_tracking_cycle_tracking_luteal_recovery", default: "Recovery slows down in this phase. Give yourself extra rest between hard sessions and focus on sleep.") }

        // MARK: - Sleep Impact

        static var menstrualSleep: String { RemoteConfigManager.shared.copyString("copy_cycle_tracking_cycle_tracking_menstrual_sleep", default: "Sleep can be disrupted by cramps or discomfort. Give yourself extra time to rest.") }
        static var follicularSleep: String { RemoteConfigManager.shared.copyString("copy_cycle_tracking_cycle_tracking_follicular_sleep", default: "Sleep quality usually gets better. Your body supports deeper, more restful sleep right now.") }
        static var ovulatorySleep: String { RemoteConfigManager.shared.copyString("copy_cycle_tracking_cycle_tracking_ovulatory_sleep", default: "Sleep is usually good, though your body temperature may rise a little, making it harder to fall asleep.") }
        static var lutealSleep: String { RemoteConfigManager.shared.copyString("copy_cycle_tracking_cycle_tracking_luteal_sleep", default: "Your body temperature runs higher, which can make sleep harder. Keep the room cool and give yourself extra wind down time.") }

        // MARK: - Nutrition Tips

        static var menstrualNutrition: String { RemoteConfigManager.shared.copyString("copy_cycle_tracking_cycle_tracking_menstrual_nutrition", default: "Eat iron-rich foods like leafy greens, red meat, and lentils. Drink plenty of water.") }
        static var follicularNutrition: String { RemoteConfigManager.shared.copyString("copy_cycle_tracking_cycle_tracking_follicular_nutrition", default: "Fuel your rising energy with whole grains, lean protein, and foods that are good for your gut.") }
        static var ovulatoryNutrition: String { RemoteConfigManager.shared.copyString("copy_cycle_tracking_cycle_tracking_ovulatory_nutrition", default: "Go lighter with plenty of fiber and colorful vegetables. Broccoli and cauliflower are great right now.") }
        static var lutealNutrition: String { RemoteConfigManager.shared.copyString("copy_cycle_tracking_cycle_tracking_luteal_nutrition", default: "Your body needs a bit more fuel. Add healthy fats and magnesium-rich foods. Dark chocolate and nuts can help with cravings.") }

        // MARK: - Exercise Recommendations

        static var menstrualExercise: String { RemoteConfigManager.shared.copyString("copy_cycle_tracking_cycle_tracking_menstrual_exercise", default: "Gentle yoga, walking, light stretching, or swimming. Do what feels good and skip anything that does not.") }
        static var follicularExercise: String { RemoteConfigManager.shared.copyString("copy_cycle_tracking_cycle_tracking_follicular_exercise", default: "Great time for hard workouts, strength training, and learning new skills. Your body is ready to perform.") }
        static var ovulatoryExercise: String { RemoteConfigManager.shared.copyString("copy_cycle_tracking_cycle_tracking_ovulatory_exercise", default: "Your peak performance window. Go for heavy lifts, sprints, and competitive activities. Push for personal bests.") }
        static var lutealExercise: String { RemoteConfigManager.shared.copyString("copy_cycle_tracking_cycle_tracking_luteal_exercise", default: "Moderate cardio, Pilates, and lighter strength work. Ease off as your energy dips toward the end of this phase.") }

        // MARK: - Section Headers

        static var howThisPhaseAffectsYou: String { RemoteConfigManager.shared.copyString("copy_cycle_tracking_cycle_tracking_how_this_phase_affects_you", default: "How This Phase Affects You") }
        static var energyAndPerformance: String { RemoteConfigManager.shared.copyString("copy_cycle_tracking_cycle_tracking_energy_and_performance", default: "Energy & Performance") }
        static var recovery: String { RemoteConfigManager.shared.copyString("copy_cycle_tracking_cycle_tracking_recovery", default: "Recovery") }
        static var sleep: String { RemoteConfigManager.shared.copyString("copy_cycle_tracking_cycle_tracking_sleep", default: "Sleep") }
        static var nutritionTips: String { RemoteConfigManager.shared.copyString("copy_cycle_tracking_cycle_tracking_nutrition_tips", default: "Nutrition Tips") }
        static var exerciseRecommendation: String { RemoteConfigManager.shared.copyString("copy_cycle_tracking_cycle_tracking_exercise_recommendation", default: "Exercise Recommendation") }
        static func recommendedFor(phase: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_cycle_tracking_cycle_tracking_recommended_for", default: "Recommended for %@"), phase) }
        static var intensity: String { RemoteConfigManager.shared.copyString("copy_cycle_tracking_cycle_tracking_intensity", default: "Intensity:") }

        // MARK: - History

        static var cycleHistory: String { RemoteConfigManager.shared.copyString("copy_cycle_tracking_cycle_tracking_cycle_history", default: "Cycle History") }
        static var notEnoughCycleData: String { RemoteConfigManager.shared.copyString("copy_cycle_tracking_cycle_tracking_not_enough_cycle_data", default: "Not enough cycle data yet") }
        static func averageCycleLength(_ days: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_cycle_tracking_cycle_tracking_average_cycle_length", default: "Average cycle length: %d days"), days) }
        static func daysCount(_ days: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_cycle_tracking_cycle_tracking_days_count", default: "%d days"), days) }

        // MARK: - Next Period

        static var nextPeriodEstimate: String { RemoteConfigManager.shared.copyString("copy_cycle_tracking_cycle_tracking_next_period_estimate", default: "Next Period Estimate") }
        static var estimatedStart: String { RemoteConfigManager.shared.copyString("copy_cycle_tracking_cycle_tracking_estimated_start", default: "Estimated Start") }
        static var days: String { RemoteConfigManager.shared.copyString("copy_cycle_tracking_cycle_tracking_days", default: "days") }
        static var daysToPeriod: String { RemoteConfigManager.shared.copyString("copy_cycle_tracking_cycle_tracking_days_to_period", default: "days to\nperiod") }
        static func basedOnCycleLength(_ length: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_cycle_tracking_cycle_tracking_based_on_cycle_length", default: "Based on your %d-day average cycle"), length) }
        static func inAboutDays(_ days: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_cycle_tracking_cycle_tracking_in_about_days", default: "In about %d days"), days) }

        // MARK: - Cycle Wheel

        static func dayOfCycle(_ day: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_cycle_tracking_cycle_tracking_day_of_cycle", default: "Day %d"), day) }
        static func ofTotal(_ total: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_cycle_tracking_cycle_tracking_of_total", default: "of %d"), total) }
        static func dayOfPhase(_ day: Int, duration: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_cycle_tracking_cycle_tracking_day_of_phase", default: "Day %d of %d"), day, duration) }

        // MARK: - Tracker Phase Display Names

        static var trackerMenstrualDisplay: String { RemoteConfigManager.shared.copyString("copy_cycle_tracking_cycle_tracking_tracker_menstrual_display", default: "Menstrual") }
        static var trackerFollicularDisplay: String { RemoteConfigManager.shared.copyString("copy_cycle_tracking_cycle_tracking_tracker_follicular_display", default: "Follicular") }
        static var trackerOvulationDisplay: String { RemoteConfigManager.shared.copyString("copy_cycle_tracking_cycle_tracking_tracker_ovulation_display", default: "Ovulation") }
        static var trackerLutealDisplay: String { RemoteConfigManager.shared.copyString("copy_cycle_tracking_cycle_tracking_tracker_luteal_display", default: "Luteal") }

        // MARK: - Tracker Phase Descriptions

        static var trackerMenstrualDescription: String { RemoteConfigManager.shared.copyString("copy_cycle_tracking_cycle_tracking_tracker_menstrual_description", default: "Energy and recovery capacity are typically at their lowest. The body is shedding the uterine lining, and iron levels may dip. Fatigue and mild discomfort are common.") }
        static var trackerFollicularDescription: String { RemoteConfigManager.shared.copyString("copy_cycle_tracking_cycle_tracking_tracker_follicular_description", default: "Rising estrogen boosts energy, mood, and recovery speed. This phase favors learning new skills and building strength as the body ramps toward peak performance.") }
        static var trackerOvulationDescription: String { RemoteConfigManager.shared.copyString("copy_cycle_tracking_cycle_tracking_tracker_ovulation_description", default: "Peak estrogen and a surge in luteinizing hormone drive the highest energy and performance potential of the cycle. Reaction time and power output tend to peak.") }
        static var trackerLutealDescription: String { RemoteConfigManager.shared.copyString("copy_cycle_tracking_cycle_tracking_tracker_luteal_description", default: "Progesterone rises while estrogen declines. Core temperature increases slightly, recovery slows, and energy gradually tapers toward the end of the phase.") }

        // MARK: - Tracker Exercise Recommendations

        static var trackerMenstrualExercise: String { RemoteConfigManager.shared.copyString("copy_cycle_tracking_cycle_tracking_tracker_menstrual_exercise", default: "Favor light movement. walking, gentle yoga, or stretching. Avoid heavy lifts or high-impact sessions if energy is low.") }
        static var trackerFollicularExercise: String { RemoteConfigManager.shared.copyString("copy_cycle_tracking_cycle_tracking_tracker_follicular_exercise", default: "Great time to push intensity. Try heavy strength training, HIIT, or learning new movement patterns. Recovery is fast.") }
        static var trackerOvulationExercise: String { RemoteConfigManager.shared.copyString("copy_cycle_tracking_cycle_tracking_tracker_ovulation_exercise", default: "Peak performance window. Go for PRs, high-intensity intervals, or competitive efforts. Stay mindful of joint laxity from elevated relaxin.") }
        static var trackerLutealExercise: String { RemoteConfigManager.shared.copyString("copy_cycle_tracking_cycle_tracking_tracker_luteal_exercise", default: "Moderate steady-state cardio and maintenance-level strength work. Reduce volume in the late luteal phase as fatigue builds.") }

        // MARK: - Tracker Sleep Impact

        static var trackerMenstrualSleep: String { RemoteConfigManager.shared.copyString("copy_cycle_tracking_cycle_tracking_tracker_menstrual_sleep", default: "Sleep may be disrupted by cramps or discomfort in the first days. Prioritize earlier bedtimes and a cool sleep environment.") }
        static var trackerFollicularSleep: String { RemoteConfigManager.shared.copyString("copy_cycle_tracking_cycle_tracking_tracker_follicular_sleep", default: "Sleep quality typically improves as estrogen rises. This is often the easiest phase for consistent, restorative sleep.") }
        static var trackerOvulationSleep: String { RemoteConfigManager.shared.copyString("copy_cycle_tracking_cycle_tracking_tracker_ovulation_sleep", default: "Sleep remains generally good, though some experience lighter sleep around the LH surge. Maintain consistent sleep timing.") }
        static var trackerLutealSleep: String { RemoteConfigManager.shared.copyString("copy_cycle_tracking_cycle_tracking_tracker_luteal_sleep", default: "Rising progesterone raises core temperature, which can reduce deep sleep. Expect more fragmented sleep in the late luteal phase.") }

        // MARK: - Tracker Nutrition Tips

        static var trackerMenstrualNutrition: String { RemoteConfigManager.shared.copyString("copy_cycle_tracking_cycle_tracking_tracker_menstrual_nutrition", default: "Focus on iron-rich foods (red meat, spinach, lentils) to offset menstrual losses. Anti-inflammatory foods like fatty fish and ginger can ease discomfort.") }
        static var trackerFollicularNutrition: String { RemoteConfigManager.shared.copyString("copy_cycle_tracking_cycle_tracking_tracker_follicular_nutrition", default: "Support rising estrogen with cruciferous vegetables and lean protein. Carbohydrate tolerance is higher. A good window for complex carbs around workouts.") }
        static var trackerOvulationNutrition: String { RemoteConfigManager.shared.copyString("copy_cycle_tracking_cycle_tracking_tracker_ovulation_nutrition", default: "Maintain balanced macros with emphasis on antioxidants and fiber. Hydration is important as energy expenditure peaks.") }
        static var trackerLutealNutrition: String { RemoteConfigManager.shared.copyString("copy_cycle_tracking_cycle_tracking_tracker_luteal_nutrition", default: "Cravings for carbs and fats are common due to increased caloric needs (~100-300 kcal/day more). Choose whole grains, magnesium-rich foods, and healthy fats.") }

        // MARK: - Tracker Recovery Impact

        static var trackerNoCycleData: String { RemoteConfigManager.shared.copyString("copy_cycle_tracking_cycle_tracking_tracker_no_cycle_data", default: "No cycle data available to assess recovery impact.") }
        static var trackerMenstrualRecoveryImpact: String { RemoteConfigManager.shared.copyString("copy_cycle_tracking_cycle_tracking_tracker_menstrual_recovery_impact", default: "Recovery is slower during menstruation. Allow extra rest between intense sessions and monitor HRV for readiness.") }
        static var trackerFollicularRecoveryImpact: String { RemoteConfigManager.shared.copyString("copy_cycle_tracking_cycle_tracking_tracker_follicular_recovery_impact", default: "Recovery is at its fastest. The body adapts well to training stimulus. shorter rest periods are feasible.") }
        static var trackerOvulationRecoveryImpact: String { RemoteConfigManager.shared.copyString("copy_cycle_tracking_cycle_tracking_tracker_ovulation_recovery_impact", default: "Recovery remains strong but joint laxity may increase injury risk. Warm up thoroughly and prioritize form.") }
        static var trackerLutealRecoveryImpact: String { RemoteConfigManager.shared.copyString("copy_cycle_tracking_cycle_tracking_tracker_luteal_recovery_impact", default: "Recovery slows as progesterone rises and core temperature climbs. Expect longer HRV recovery and higher resting heart rate.") }

        static var trackerNoCycleExerciseFallback: String { RemoteConfigManager.shared.copyString("copy_cycle_tracking_cycle_tracking_tracker_no_cycle_exercise_fallback", default: "Track at least one menstrual period to receive phase-specific training advice.") }
    }
}
