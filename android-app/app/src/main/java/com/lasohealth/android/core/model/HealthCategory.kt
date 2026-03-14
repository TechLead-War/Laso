package com.lasohealth.android.core.model

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.DirectionsRun
import androidx.compose.material.icons.automirrored.filled.DirectionsWalk
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Hearing
import androidx.compose.material.icons.filled.Hotel
import androidx.compose.material.icons.filled.Air
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Psychology
import androidx.compose.material.icons.filled.Restaurant
import androidx.compose.material.icons.filled.SelfImprovement
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import com.lasohealth.android.ui.theme.CategoryActivity
import com.lasohealth.android.ui.theme.CategoryBody
import com.lasohealth.android.ui.theme.CategoryHearing
import com.lasohealth.android.ui.theme.CategoryHeart
import com.lasohealth.android.ui.theme.CategoryMindfulness
import com.lasohealth.android.ui.theme.CategoryMobility
import com.lasohealth.android.ui.theme.CategoryNutrition
import com.lasohealth.android.ui.theme.CategoryRespiratory
import com.lasohealth.android.ui.theme.CategorySleep

// iOS SF Symbol → Material Icon mapping:
// heart.fill → Favorite, bed.double.fill → Hotel, figure.run → DirectionsRun,
// figure.stand → SelfImprovement, lungs.fill → Air (use Psychology as closest),
// brain.head.profile → Psychology, figure.walk.motion → DirectionsWalk,
// fork.knife → Restaurant, ear.fill → Hearing

enum class HealthCategory(
    val displayName: String,
    val shortName: String,
    val accentColor: Color,
    val icon: ImageVector,
) {
    HEART("Heart & Cardio", "Heart", CategoryHeart, Icons.Filled.Favorite),
    SLEEP("Sleep", "Sleep", CategorySleep, Icons.Filled.Hotel),
    ACTIVITY("Activity", "Activity", CategoryActivity, Icons.AutoMirrored.Filled.DirectionsRun),
    BODY("Body & Vitals", "Body", CategoryBody, Icons.Filled.Person),
    RESPIRATORY("Respiratory", "Lungs", CategoryRespiratory, Icons.Filled.Air),
    MINDFULNESS("Mindfulness", "Mind", CategoryMindfulness, Icons.Filled.SelfImprovement),
    MOBILITY("Mobility", "Mobility", CategoryMobility, Icons.AutoMirrored.Filled.DirectionsWalk),
    NUTRITION("Nutrition", "Nutrition", CategoryNutrition, Icons.Filled.Restaurant),
    HEARING("Hearing", "Hearing", CategoryHearing, Icons.Filled.Hearing),
}
