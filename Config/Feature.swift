import Foundation

/// Every gatable feature in the app.
/// Add new features here, then assign them to tiers in FeatureConfig.
enum Feature: String, CaseIterable, Identifiable, Codable {
    var id: String { rawValue }

    // MARK: - Dashboard & Scores
    case healthScore            // Overall health score on home screen
    case categoryScores         // Per-category scores

    // MARK: - Metrics
    case basicMetrics           // Limited set of metric detail views
    case allMetrics             // All 48+ metric detail views

    // MARK: - Trends & History
    case sevenDayTrends         // 7-day trend data
    case extendedHistory        // 30D / 3M / 6M period selectors

    // MARK: - Risk & Predictions
    case riskPredictions        // Health risk assessments
    case focusAreas             // "Your Focus Areas" section

    // MARK: - Insights
    case basicInsights          // Top 1 insight
    case allInsights            // All insights + insight detail

    // MARK: - Live
    case liveTab                // Live vitals tab

    // MARK: - Export & Reports
    case exportReport           // Web/PDF health report export

    // MARK: - Advanced
    case advancedAnalytics      // Detailed baselines, moving averages, trend slopes

    // MARK: - Advanced Insights
    case correlationInsights    // Cross-metric correlation analysis
    case recoveryInsights       // Post-workout recovery tracking
    case workoutEffectiveness   // Workout consistency & efficiency
    case sleepPerformanceLink   // Sleep → next-day performance link
    case weeklyPatterns         // Day-of-week pattern analysis
    case personalRecords        // Rolling PRs, milestones, streaks

    var displayName: String {
        switch self {
        case .healthScore: return "Health Score"
        case .categoryScores: return "Category Scores"
        case .basicMetrics: return "Basic Metrics"
        case .allMetrics: return "All Metrics"
        case .sevenDayTrends: return "7-Day Trends"
        case .extendedHistory: return "Extended History"
        case .riskPredictions: return "Risk Predictions"
        case .focusAreas: return "Focus Areas"
        case .basicInsights: return "Basic Insights"
        case .allInsights: return "All Insights"
        case .liveTab: return "Live Vitals"
        case .exportReport: return "Export Reports"
        case .advancedAnalytics: return "Advanced Analytics"
        case .correlationInsights: return "Correlations"
        case .recoveryInsights: return "Recovery Insights"
        case .workoutEffectiveness: return "Workout Effectiveness"
        case .sleepPerformanceLink: return "Sleep & Performance"
        case .weeklyPatterns: return "Weekly Patterns"
        case .personalRecords: return "Personal Records"
        }
    }

    var description: String {
        switch self {
        case .healthScore: return "Your overall health score based on all tracked metrics"
        case .categoryScores: return "Scores for each health category"
        case .basicMetrics: return "Track your top 3 health metrics"
        case .allMetrics: return "Deep-dive into all 48+ health metrics"
        case .sevenDayTrends: return "See how your metrics changed over the past week"
        case .extendedHistory: return "View trends over 30 days, 3 months, and 6 months"
        case .riskPredictions: return "AI-powered health risk predictions combining multiple signals"
        case .focusAreas: return "Personalized recommendations on what to improve first"
        case .basicInsights: return "Your most important health insight"
        case .allInsights: return "All actionable health insights with recommendations"
        case .liveTab: return "Real-time heart rate, SpO2, and activity monitoring"
        case .exportReport: return "Export shareable health reports"
        case .advancedAnalytics: return "Baselines, moving averages, trend slopes, and more"
        case .correlationInsights: return "Discover how your health metrics influence each other"
        case .recoveryInsights: return "Track post-workout recovery and detect overtraining"
        case .workoutEffectiveness: return "Measure workout consistency, VO2 Max response, and calorie efficiency"
        case .sleepPerformanceLink: return "See how sleep duration and quality affect next-day performance"
        case .weeklyPatterns: return "Identify your strongest and weakest days of the week"
        case .personalRecords: return "Track rolling PRs, milestones, and activity streaks"
        }
    }
}
