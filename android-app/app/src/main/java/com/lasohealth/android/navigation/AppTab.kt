package com.lasohealth.android.navigation

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.BarChart
import androidx.compose.material.icons.outlined.FavoriteBorder
import androidx.compose.material.icons.outlined.MonitorHeart
import androidx.compose.ui.graphics.vector.ImageVector

enum class AppTab(
    val route: String,
    val label: String,
    val icon: ImageVector,
) {
    HOME("home", "Today", Icons.Outlined.FavoriteBorder),
    LIVE("live", "Live", Icons.Outlined.MonitorHeart),
    EXPLORE("explore", "Explore", Icons.Outlined.BarChart),
    ;

    companion object {
        fun fromRoute(route: String?): AppTab =
            entries.firstOrNull { it.route == route } ?: HOME
    }
}
