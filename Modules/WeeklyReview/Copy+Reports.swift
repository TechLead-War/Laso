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
        static let worstMonth = "Lowest Month"
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
            "Average score: \(score). \(message)"
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
        static let firstMonthNoComparison = "First month. No comparison yet."
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
                "You are hitting your \(currentTarget)/day target. Next week, we will bump it up to \(nextTarget)/day."
            }
            static func plateauing(currentTarget: String) -> String {
                "You are close to your \(currentTarget)/day target. Let us hold here this week and build the habit before pushing higher."
            }
            static func struggling(currentTarget: String, nextTarget: String) -> String {
                "This week was tough at \(currentTarget)/day. We will drop to \(nextTarget)/day next week so it feels doable."
            }
        }

        // MARK: - Weekly Review View

        enum WeeklyReviewView {
            static let title = "Your Weekly Review"
            static func score(_ score: Int) -> String { "Score \(score)" }
            static func coachTarget(_ steps: String) -> String { "Coach target: \(steps)/day" }
            static let keepSyncing = "Keep syncing health data for a few days and check back."
            static let firstWeekNoComparison = "First week. No comparison yet."
            static func consistencyPayingOff(_ category: String) -> String {
                "Consistency in \(category) is paying off. Keep the momentum going into next week."
            }
            static let stableWeek = "A stable week across the board."
            static let noMajorChanges = "No major changes. Consistency is a strength."
            static let currentTarget = "Current target"
            static let currentAverage = "Current average"
            static let status = "Status"
            static let nextWeekTarget = "Next week target"
            static func stepTarget(_ steps: String) -> String { "Step target: \(steps)/day" }
            static let poweredByModel = "Powered by your personal health data"
        }
    }
}
