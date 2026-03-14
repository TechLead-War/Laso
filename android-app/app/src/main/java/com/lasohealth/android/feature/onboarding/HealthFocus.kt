package com.lasohealth.android.feature.onboarding

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Bedtime
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.material.icons.filled.DirectionsRun
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.FitnessCenter
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector

enum class HealthFocus(
    val displayName: String,
    val icon: ImageVector,
    val color: Color,
) {
    SLEEP("Sleep", Icons.Filled.Bedtime, Color(0xFF5856D6)),
    FITNESS("Fitness", Icons.Filled.DirectionsRun, Color(0xFF4F8A62)),
    HEART_HEALTH("Heart Health", Icons.Filled.Favorite, Color(0xFFCC4B4C)),
    WEIGHT_BODY("Weight & Body", Icons.Filled.FitnessCenter, Color(0xFFD16C37)),
    RECOVERY("Recovery", Icons.Filled.Bolt, Color(0xFFAF52DE)),
}
