package com.lasohealth.android.core.model

enum class HealthMetric(
    val displayName: String,
    val unit: String,
    val category: HealthCategory,
    val higherIsBetter: Boolean,
) {
    HEART_RATE("Heart Rate", "bpm", HealthCategory.HEART, false),
    RESTING_HEART_RATE("Resting Heart Rate", "bpm", HealthCategory.HEART, false),
    HEART_RATE_VARIABILITY("Heart Rate Variability", "ms", HealthCategory.HEART, true),
    WALKING_HEART_RATE_AVERAGE("Walking HR Average", "bpm", HealthCategory.HEART, false),
    HEART_RATE_RECOVERY("HR Recovery", "bpm", HealthCategory.HEART, true),
    ATRIAL_FIBRILLATION_BURDEN("AFib Burden", "%", HealthCategory.HEART, false),
    PERIPHERAL_PERFUSION_INDEX("Perfusion Index", "%", HealthCategory.HEART, false),

    SLEEP_DURATION("Sleep Duration", "hrs", HealthCategory.SLEEP, true),
    SLEEP_REM("REM Sleep", "hrs", HealthCategory.SLEEP, true),
    SLEEP_DEEP("Deep Sleep", "hrs", HealthCategory.SLEEP, true),
    SLEEP_CORE("Core Sleep", "hrs", HealthCategory.SLEEP, false),
    SLEEP_AWAKE("Awake Time", "hrs", HealthCategory.SLEEP, false),
    SLEEP_BREATHING_DISTURBANCES("Breathing Disturbances", "events/hr", HealthCategory.SLEEP, false),

    STEPS("Steps", "steps", HealthCategory.ACTIVITY, true),
    ACTIVE_CALORIES("Active Calories", "kcal", HealthCategory.ACTIVITY, true),
    BASAL_CALORIES("Basal Calories", "kcal", HealthCategory.ACTIVITY, false),
    EXERCISE_MINUTES("Exercise Minutes", "min", HealthCategory.ACTIVITY, true),
    STAND_HOURS("Stand Hours", "hrs", HealthCategory.ACTIVITY, true),
    DISTANCE_WALKING_RUNNING("Distance", "km", HealthCategory.ACTIVITY, true),
    FLIGHTS_CLIMBED("Flights Climbed", "flights", HealthCategory.ACTIVITY, true),
    DISTANCE_CYCLING("Cycling Distance", "km", HealthCategory.ACTIVITY, true),
    DISTANCE_SWIMMING("Swimming Distance", "km", HealthCategory.ACTIVITY, true),
    SWIMMING_STROKE_COUNT("Swimming Strokes", "strokes", HealthCategory.ACTIVITY, true),
    APPLE_MOVE_TIME("Move Time", "min", HealthCategory.ACTIVITY, true),
    RUNNING_POWER("Running Power", "W", HealthCategory.ACTIVITY, true),
    RUNNING_GROUND_CONTACT_TIME("Ground Contact Time", "ms", HealthCategory.ACTIVITY, false),
    RUNNING_VERTICAL_OSCILLATION("Vertical Oscillation", "cm", HealthCategory.ACTIVITY, false),
    RUNNING_STRIDE_LENGTH("Running Stride", "m", HealthCategory.ACTIVITY, true),
    UNDERWATER_DEPTH("Dive Depth", "m", HealthCategory.ACTIVITY, true),
    WATER_TEMPERATURE("Water Temperature", "C", HealthCategory.ACTIVITY, false),

    WEIGHT("Weight", "kg", HealthCategory.BODY, false),
    BMI("BMI", "", HealthCategory.BODY, false),
    BODY_FAT_PERCENTAGE("Body Fat %", "%", HealthCategory.BODY, false),
    BLOOD_PRESSURE_SYSTOLIC("Systolic BP", "mmHg", HealthCategory.BODY, false),
    BLOOD_PRESSURE_DIASTOLIC("Diastolic BP", "mmHg", HealthCategory.BODY, false),
    BODY_TEMPERATURE("Body Temperature", "C", HealthCategory.BODY, false),
    APPLE_SLEEPING_WRIST_TEMPERATURE("Wrist Temperature", "C", HealthCategory.BODY, false),
    LEAN_BODY_MASS("Lean Body Mass", "kg", HealthCategory.BODY, true),
    WAIST_CIRCUMFERENCE("Waist Circumference", "cm", HealthCategory.BODY, false),

    VO2_MAX("VO2 Max", "mL/kg/min", HealthCategory.RESPIRATORY, true),
    BLOOD_OXYGEN("Blood Oxygen", "%", HealthCategory.RESPIRATORY, true),
    RESPIRATORY_RATE("Respiratory Rate", "br/min", HealthCategory.RESPIRATORY, false),
    PEAK_EXPIRATORY_FLOW_RATE("Peak Flow Rate", "L/min", HealthCategory.RESPIRATORY, true),
    FORCED_VITAL_CAPACITY("Forced Vital Capacity", "L", HealthCategory.RESPIRATORY, true),
    FORCED_EXPIRATORY_VOLUME_1("FEV1", "L", HealthCategory.RESPIRATORY, true),

    MINDFUL_MINUTES("Mindful Minutes", "min", HealthCategory.MINDFULNESS, true),
    TIME_IN_DAYLIGHT("Time in Daylight", "min", HealthCategory.MINDFULNESS, true),
    ELECTRODERMAL_ACTIVITY("Electrodermal Activity", "uS", HealthCategory.MINDFULNESS, false),

    WALKING_SPEED("Walking Speed", "km/h", HealthCategory.MOBILITY, true),
    WALKING_STEP_LENGTH("Step Length", "cm", HealthCategory.MOBILITY, true),
    WALKING_ASYMMETRY("Walking Asymmetry", "%", HealthCategory.MOBILITY, false),
    WALKING_DOUBLE_SUPPORT_PERCENTAGE("Double Support %", "%", HealthCategory.MOBILITY, false),
    STAIR_ASCENT_SPEED("Stair Ascent Speed", "m/s", HealthCategory.MOBILITY, true),
    STAIR_DESCENT_SPEED("Stair Descent Speed", "m/s", HealthCategory.MOBILITY, true),
    SIX_MINUTE_WALK_TEST_DISTANCE("6-Min Walk Distance", "m", HealthCategory.MOBILITY, true),
    WALKING_STEADINESS("Walking Steadiness", "%", HealthCategory.MOBILITY, true),
    NUMBER_OF_TIMES_FALLEN("Falls Detected", "", HealthCategory.MOBILITY, false),

    WATER_INTAKE("Water Intake", "mL", HealthCategory.NUTRITION, true),
    CAFFEINE_INTAKE("Caffeine", "mg", HealthCategory.NUTRITION, false),
    PROTEIN_INTAKE("Protein", "g", HealthCategory.NUTRITION, true),
    FIBER_INTAKE("Fiber", "g", HealthCategory.NUTRITION, true),
    SUGAR_INTAKE("Sugar", "g", HealthCategory.NUTRITION, false),
    SODIUM_INTAKE("Sodium", "mg", HealthCategory.NUTRITION, false),
    TOTAL_CALORIES_INTAKE("Calories (Diet)", "kcal", HealthCategory.NUTRITION, false),
    CARBOHYDRATE_INTAKE("Carbs", "g", HealthCategory.NUTRITION, false),
    FAT_INTAKE("Fat", "g", HealthCategory.NUTRITION, false),

    BLOOD_GLUCOSE("Blood Glucose", "mg/dL", HealthCategory.BODY, false),
    INSULIN_DELIVERY("Insulin Delivery", "IU", HealthCategory.BODY, false),

    WORKOUT_COUNT("Workout Count", "", HealthCategory.ACTIVITY, true),
    WORKOUT_DURATION("Workout Duration", "min", HealthCategory.ACTIVITY, true),

    HEADPHONE_AUDIO_EXPOSURE("Headphone Audio", "dB", HealthCategory.HEARING, false),
    ENVIRONMENTAL_AUDIO_EXPOSURE("Environmental Sound", "dB", HealthCategory.HEARING, false),
    ;

    companion object {
        fun byCategory(category: HealthCategory): List<HealthMetric> =
            entries.filter { it.category == category }
    }
}
