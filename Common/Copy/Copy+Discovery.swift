import Foundation

extension Copy {
    enum Discovery {

        // MARK: - Engine Templates

        static func conditionalHeadline(effect: String, direction: String, diff: String, unit: String, thresholdLabel: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_discovery_discovery_conditional_headline", default: "Your %@ %@ by %@ %@ when %@"), effect, direction, diff, unit, thresholdLabel)
        }
        static func evidenceMonths(days: Int, months: Int) -> String {
            let suffix = months == 1
                ? RemoteConfigManager.shared.copyString("copy_discovery_evidence_months_singular", default: "month")
                : RemoteConfigManager.shared.copyString("copy_discovery_evidence_months_plural", default: "months")
            return String(format: RemoteConfigManager.shared.copyString("copy_discovery_evidence_months", default: "Based on %d days over %d %@"), days, months, suffix)
        }
        static func ladderHeadline(causeFormatted: String, causeUnit: String, effect: String, direction: String, diff: String, effectUnit: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_discovery_ladder_headline", default: "The magic number is %@ %@. Your %@ %@ by %@ %@ past that point"), causeFormatted, causeUnit, effect, direction, diff, effectUnit)
        }
        static func ladderDetail(causeFormatted: String, causeUnit: String, effect: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_discovery_ladder_detail", default: "Below %@ %@, your %@ stays flat. Above it, there's a clear jump."), causeFormatted, causeUnit, effect)
        }
        static func evidenceDataPoints(samples: Int, periodLabel: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_discovery_evidence_data_points", default: "Based on %d data points over %@"), samples, periodLabel)
        }
        static func quietShiftHeadline(metric: String, direction: String, percent: String, periodLabel: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_discovery_quiet_shift_headline", default: "Your %@ has quietly %@ %@%% over the %@"), metric, direction, percent, periodLabel)
        }
        static func quietShiftDetail(absoluteDetail: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_discovery_quiet_shift_detail", default: "This is a gradual shift you might not notice day to day%@."), absoluteDetail)
        }
        static func bracketHeadline(metric: String, bracket: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_discovery_bracket_headline", default: "Your %@ this month is in your %@ of all time"), metric, bracket)
        }
        static func bracketDetailExceptional(metric: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_discovery_bracket_detail_exceptional", default: "This is an exceptional period for your %@. Keep doing what you're doing."), metric)
        }
        static func bracketDetailUnusual(metric: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_discovery_bracket_detail_unusual", default: "Your %@ is at an unusual level. Worth paying attention to."), metric)
        }
        static func compoundHeadline(condA: String, condB: String, outcome: String, percent: String, direction: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_discovery_compound_headline", default: "When you %@ AND %@, your %@ is %@%% %@"), condA, condB, outcome, percent, direction)
        }
        static func compoundDetail(outcome: String, bothFormatted: String, neitherFormatted: String, unit: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_discovery_compound_detail", default: "The combination matters more than either habit alone. On days you do both, %@ averages %@ %@ vs %@ %@."), outcome, bothFormatted, unit, neitherFormatted, unit)
        }
        static func averageEffectDetail(effect: String, aboveFormatted: String, belowFormatted: String, unit: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_discovery_average_effect_detail", default: "Average %@: %@ %@ (with) vs %@ %@ (without)."), effect, aboveFormatted, unit, belowFormatted, unit)
        }
        static func consistentDayDetail(topDayName: String, metric: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_discovery_consistent_day_detail", default: "Your weekly pattern is consistent. %@s tend to be your strongest day for %@."), topDayName, metric)
        }

        // MARK: - CTA Page

        static var ctaTitle: String { RemoteConfigManager.shared.copyString("copy_discovery_cta_title", default: "Your Dashboard is Ready") }
        static var ctaSubtitle: String { RemoteConfigManager.shared.copyString("copy_discovery_cta_subtitle", default: "Track these patterns and more. Updated every time you open the app.") }

        // MARK: - Accessibility

        static var continueToDashboard: String { RemoteConfigManager.shared.copyString("copy_discovery_continue_to_dashboard", default: "Continue to dashboard") }

        // MARK: - Soft Variants (legacy literal text used in DiscoveryView)

        static var analyzedHistory: String { RemoteConfigManager.shared.copyString("copy_discovery_analyzed_history", default: "We analyzed your health history") }
        static var hereWhatWeFound: String { RemoteConfigManager.shared.copyString("copy_discovery_here_what_we_found", default: "Here is what we found") }
        static var swipeToExplore: String { RemoteConfigManager.shared.copyString("copy_discovery_swipe_to_explore", default: "Swipe to explore") }

        // MARK: - Lifted view literals
        static var closesDiscoveryAndOpensYourDashboardHint: String { RemoteConfigManager.shared.copyString("copy_discovery_closes_discovery_and_opens_your_dashboard_hint", default: "Closes discovery and opens your dashboard") }
    }
}
