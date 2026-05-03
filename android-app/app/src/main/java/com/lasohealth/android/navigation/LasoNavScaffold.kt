package com.lasohealth.android.navigation

import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.lasohealth.android.core.data.HealthDataRepository
import com.lasohealth.android.core.model.HealthCategory
import com.lasohealth.android.core.model.HealthMetric
import com.lasohealth.android.feature.detail.AchievementsScreen
import com.lasohealth.android.feature.detail.BrainHealthScreen
import com.lasohealth.android.feature.detail.BreathworkScreen
import com.lasohealth.android.feature.detail.CategoryDetailScreen
import com.lasohealth.android.feature.detail.ConnectedDevicesScreen
import com.lasohealth.android.feature.detail.CorrelationsDetailScreen
import com.lasohealth.android.feature.detail.CycleDetailScreen
import com.lasohealth.android.feature.detail.DeviceDetailScreen
import com.lasohealth.android.feature.detail.DeviceSetupGuideScreen
import com.lasohealth.android.feature.detail.DiscoveryScreen
import com.lasohealth.android.feature.detail.HealthRiskDetailScreen
import com.lasohealth.android.feature.detail.HealthStateTimelineScreen
import com.lasohealth.android.feature.detail.InsightsDetailScreen
import com.lasohealth.android.feature.detail.MetricDetailScreen
import com.lasohealth.android.feature.detail.PaywallScreen
import com.lasohealth.android.feature.detail.PerformanceProfileScreen
import com.lasohealth.android.feature.detail.RecoveryInfoScreen
import com.lasohealth.android.feature.detail.ScoreGuideScreen
import com.lasohealth.android.feature.detail.SimulationScreen
import com.lasohealth.android.feature.detail.SleepCoachScreen
import com.lasohealth.android.feature.detail.StrainDetailScreen
import com.lasohealth.android.feature.detail.StressMonitorScreen
import com.lasohealth.android.feature.detail.TodayWorkoutScreen
import com.lasohealth.android.feature.detail.VitalityDetailScreen
import com.lasohealth.android.feature.detail.WeeklyReviewScreen
import com.lasohealth.android.feature.explore.ExploreScreen
import com.lasohealth.android.feature.home.HomeScreen
import com.lasohealth.android.feature.journal.ExpandedJournalScreen
import com.lasohealth.android.feature.journal.JournalEntryScreen
import com.lasohealth.android.feature.journal.JournalInsightsScreen
import com.lasohealth.android.feature.live.LiveScreen
import com.lasohealth.android.feature.reports.AnnualReportScreen
import com.lasohealth.android.feature.reports.MonthlyReviewScreen
import com.lasohealth.android.feature.settings.NotificationsSettingsScreen
import com.lasohealth.android.feature.settings.SettingsScreen

@Composable
fun LasoNavScaffold(
    repository: HealthDataRepository,
) {
    val navController = rememberNavController()
    val homeState = remember(repository) { repository.homeState() }
    val liveState = remember(repository) { repository.liveState() }
    val exploreState = remember(repository) { repository.exploreState() }
    val backStackEntry by navController.currentBackStackEntryAsState()
    val currentRoute = backStackEntry?.destination?.route

    // Determine if we should show bottom bar (hide on detail screens)
    val showBottomBar = currentRoute in AppTab.entries.map { it.route }

    Scaffold(
        bottomBar = {
            if (showBottomBar) {
                val currentTab = AppTab.fromRoute(currentRoute)
                NavigationBar(
                    containerColor = MaterialTheme.colorScheme.surface.copy(alpha = 0.94f),
                    tonalElevation = 0.dp,
                ) {
                    AppTab.entries.forEach { tab ->
                        val selected = currentTab == tab
                        NavigationBarItem(
                            selected = selected,
                            onClick = {
                                navController.navigate(tab.route) {
                                    popUpTo(navController.graph.findStartDestination().id) {
                                        saveState = true
                                    }
                                    launchSingleTop = true
                                    restoreState = true
                                }
                            },
                            icon = {
                                Icon(
                                    imageVector = tab.icon,
                                    contentDescription = tab.label,
                                )
                            },
                            label = {
                                Text(
                                    text = tab.label,
                                    fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal,
                                )
                            },
                            colors = NavigationBarItemDefaults.colors(
                                selectedIconColor = MaterialTheme.colorScheme.onBackground,
                                selectedTextColor = MaterialTheme.colorScheme.onBackground,
                                unselectedIconColor = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
                                unselectedTextColor = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
                                indicatorColor = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.08f),
                            ),
                        )
                    }
                }
            }
        },
    ) { innerPadding ->
        NavHost(
            navController = navController,
            startDestination = AppTab.HOME.route,
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding),
        ) {
            // Main tabs
            composable(AppTab.HOME.route) {
                HomeScreen(state = homeState, navController = navController)
            }
            composable(AppTab.LIVE.route) {
                LiveScreen(state = liveState, navController = navController)
            }
            composable(AppTab.EXPLORE.route) {
                ExploreScreen(state = exploreState, navController = navController)
            }

            // Settings
            composable(AppRoute.Settings.route) {
                SettingsScreen(navController = navController, repository = repository)
            }
            composable(AppRoute.NotificationsSettings.route) {
                NotificationsSettingsScreen(navController = navController)
            }

            // Score Guide
            composable(AppRoute.ScoreGuide.route) {
                ScoreGuideScreen(
                    score = homeState.score,
                    navController = navController,
                )
            }

            // Insights Detail
            composable(AppRoute.InsightsDetail.route) {
                InsightsDetailScreen(
                    insights = homeState.insights,
                    navController = navController,
                )
            }

            // Weekly Review
            composable(AppRoute.WeeklyReview.route) {
                WeeklyReviewScreen(
                    state = repository.weeklyReviewDetailState(),
                    navController = navController,
                )
            }

            // Achievements
            composable(AppRoute.Achievements.route) {
                AchievementsScreen(
                    state = repository.achievementsState(),
                    navController = navController,
                )
            }

            // Connected Devices
            composable(AppRoute.ConnectedDevices.route) {
                ConnectedDevicesScreen(
                    state = repository.connectedDevicesState(),
                    navController = navController,
                )
            }

            // Paywall
            composable(AppRoute.Paywall.route) {
                PaywallScreen(navController = navController)
            }

            // Feature Detail Screens
            composable(AppRoute.VitalityDetail.route) {
                VitalityDetailScreen(
                    state = repository.vitalityDetailState(),
                    navController = navController,
                )
            }
            composable(AppRoute.StrainDetail.route) {
                StrainDetailScreen(
                    state = repository.strainDetailState(),
                    navController = navController,
                )
            }
            composable(AppRoute.StressMonitor.route) {
                StressMonitorScreen(
                    state = repository.stressMonitorState(),
                    navController = navController,
                )
            }
            composable(AppRoute.BrainHealth.route) {
                BrainHealthScreen(
                    state = repository.brainHealthState(),
                    navController = navController,
                )
            }
            composable(AppRoute.SleepCoach.route) {
                SleepCoachScreen(
                    state = repository.sleepCoachState(),
                    navController = navController,
                )
            }
            composable(AppRoute.CycleDetail.route) {
                CycleDetailScreen(
                    state = repository.cycleDetailState(),
                    navController = navController,
                )
            }
            composable(AppRoute.HealthStateTimeline.route) {
                HealthStateTimelineScreen(
                    state = repository.healthStateTimelineState(),
                    navController = navController,
                )
            }
            composable(AppRoute.CorrelationsDetail.route) {
                CorrelationsDetailScreen(
                    correlations = exploreState.correlations,
                    navController = navController,
                )
            }

            // New screens matching iOS parity
            composable(AppRoute.Breathwork.route) {
                BreathworkScreen(navController = navController)
            }
            composable(AppRoute.PerformanceProfile.route) {
                PerformanceProfileScreen(
                    state = repository.performanceProfileState(),
                    navController = navController,
                )
            }
            composable(AppRoute.Simulation.route) {
                SimulationScreen(navController = navController)
            }
            composable(AppRoute.Discovery.route) {
                DiscoveryScreen(
                    score = homeState.score,
                    categoryScores = exploreState.categoryScores.map { it.category.shortName to it.score },
                    insights = homeState.insights.map { it.title },
                    onDismiss = { navController.popBackStack() },
                )
            }
            composable(AppRoute.DeviceSetupGuide.route) {
                DeviceSetupGuideScreen(navController = navController)
            }
            composable(AppRoute.AnnualReport.route) {
                AnnualReportScreen(
                    state = repository.annualReportState(),
                    navController = navController,
                )
            }
            composable(AppRoute.MonthlyReview.route) {
                MonthlyReviewScreen(
                    state = repository.monthlyReviewState(),
                    navController = navController,
                )
            }
            composable(AppRoute.JournalEntry.route) {
                JournalEntryScreen(navController = navController)
            }
            composable(AppRoute.JournalList.route) {
                ExpandedJournalScreen(navController = navController)
            }
            composable(AppRoute.JournalInsights.route) {
                JournalInsightsScreen(navController = navController)
            }
            composable(AppRoute.RecoveryInfo.route) {
                RecoveryInfoScreen(
                    score = homeState.dailyScore,
                    navController = navController,
                )
            }
            composable(AppRoute.TodayWorkout.route) {
                TodayWorkoutScreen(
                    state = repository.todayWorkoutState(),
                    navController = navController,
                )
            }

            // Parameterized routes
            composable(
                route = AppRoute.MetricDetail.route,
                arguments = listOf(navArgument("metricId") { type = NavType.StringType }),
            ) { backStack ->
                val metricId = backStack.arguments?.getString("metricId") ?: return@composable
                val metric = HealthMetric.entries.firstOrNull { it.name == metricId } ?: return@composable
                MetricDetailScreen(
                    state = repository.metricDetailState(metric),
                    navController = navController,
                )
            }
            composable(
                route = AppRoute.CategoryDetail.route,
                arguments = listOf(navArgument("categoryId") { type = NavType.StringType }),
            ) { backStack ->
                val categoryId = backStack.arguments?.getString("categoryId") ?: return@composable
                val category = HealthCategory.entries.firstOrNull { it.name == categoryId } ?: return@composable
                CategoryDetailScreen(
                    state = repository.categoryDetailState(category),
                    navController = navController,
                )
            }
            composable(
                route = AppRoute.DeviceDetail.route,
                arguments = listOf(navArgument("deviceId") { type = NavType.StringType }),
            ) { backStack ->
                val deviceId = backStack.arguments?.getString("deviceId") ?: return@composable
                DeviceDetailScreen(
                    state = repository.deviceDetailState(deviceId),
                    navController = navController,
                )
            }
            composable(
                route = AppRoute.HealthRiskDetail.route,
                arguments = listOf(navArgument("riskId") { type = NavType.StringType }),
            ) { backStack ->
                val riskId = backStack.arguments?.getString("riskId") ?: return@composable
                HealthRiskDetailScreen(
                    state = repository.healthRiskDetailState(riskId),
                    navController = navController,
                )
            }
        }
    }
}
