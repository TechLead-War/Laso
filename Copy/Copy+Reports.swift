import Foundation

extension Copy {
    enum Reports {

        // MARK: - Annual Report

        static func yearInReview(_ year: Int) -> String { "\(year) Year in Review" }
        static let shareAnnualReport = "Share annual report"
        static let annualScore = "Annual Score"

        // MARK: - Hero

        static func streakDayRecord(_ days: Int) -> String { "\(days)-day streak record" }
        static let jan = "Jan"
        static let dec = "Dec"
        static func yearsYounger(_ years: Int) -> String { "\(years)y younger" }
        static func yearsOlder(_ years: Int) -> String { "\(years)y older" }

        // MARK: - Stats

        static let annualStats = "Annual Stats"
        static let activeDays = "Active Days"
        static let exerciseHours = "Exercise Hours"
        static let exerciseHrs = "Exercise Hrs"
        static let distanceKm = "Distance (km)"
        static let avgStepsPerDay = "Avg Steps/Day"
        static let avgSleep = "Avg Sleep"
        static let sevenPlusHourNights = "7+ Hour Nights"

        // MARK: - Score Journey

        static let scoreJourney = "Score Journey"
        static let monthlyAverages = "Monthly Averages"
        static let bestMonth = "Best Month"
        static let worstMonth = "Worst Month"
        static let yearOverYear = "Year over Year"
        static func yearOverYearDetail(prevYear: Int, prevScore: Int, curYear: Int, curScore: Int) -> String {
            "\(prevYear) avg: \(prevScore) \u{2192} \(curYear) avg: \(curScore)"
        }

        // MARK: - Discoveries

        static let topDiscoveries = "Top Discoveries"

        // MARK: - Milestones

        static let milestonesAndRecords = "Milestones & Records"
        static let bestStreak = "Best Streak"

        // MARK: - Looking Ahead

        static func lookingAhead(_ year: Int) -> String { "Looking Ahead to \(year)" }
        static let biggestOpportunities = "Biggest Opportunities"
        static func averageScoreMessage(score: Int, message: String) -> String {
            "Average score: \(score) \u{2014} \(message)"
        }
        static let suggestedFocusAreas = "Suggested Focus Areas"
        static func heresTo(_ year: Int) -> String { "Here\u{2019}s to a healthier \(year)" }

        // Opportunity messages
        static let keepUpGreatWork = "keep up the great work"
        static let smallImprovements = "small improvements can make a big difference"
        static let significantRoom = "significant room for growth"
        static let priorityArea = "a priority area for next year"

        // MARK: - Category Section

        static let categorySummary = "Category Summary"
        static let mostImproved = "Most Improved"
        static func mostImprovedDetail(_ category: String) -> String {
            "\(category) showed the most improvement this year"
        }

        // MARK: - Monthly Review

        static func deltaFromLastMonth(_ delta: Int) -> String {
            "\(delta >= 0 ? "+" : "")\(delta) from last month"
        }
        static let firstMonthNoComparison = "First month \u{2014} no comparison yet"
        static let notEnoughData = "Not enough data"
        static let categoryPerformance = "Category Performance"
        static let behaviorCorrelations = "Behavior Correlations"
        static let helpedRecovery = "Helped Recovery"
        static let hurtRecovery = "Hurt Recovery"

        // MARK: - Share Card

        static let trackHealthWithLaso = "Track your health with Laso"

        // MARK: - Weekly Review

        enum WeeklyReview {
            static func keepingUp(currentTarget: String, nextTarget: String) -> String {
                "You are consistently hitting your \(currentTarget)/day target. Next week, we will progress to \(nextTarget)/day."
            }
            static func plateauing(currentTarget: String) -> String {
                "You are close to your \(currentTarget)/day target. We will hold steady this week and build consistency before increasing."
            }
            static func struggling(currentTarget: String, nextTarget: String) -> String {
                "This week looked tough at \(currentTarget)/day. We will reduce next week to \(nextTarget)/day so the plan stays realistic."
            }
        }
    }
}
