import SwiftUI
import Charts

// MARK: - Annual Report View

struct AnnualReportView: View {
    let year: Int
    let monthlyScores: [(month: Int, score: Int)]
    let annualStats: AnnualStats
    let categoryScores: [AnnualCategoryScore]
    let discoveries: [AnnualDiscovery]
    let records: [AnnualRecord]

    var overallScore: Int {
        guard !monthlyScores.isEmpty else { return 0 }
        return monthlyScores.map(\.score).reduce(0, +) / monthlyScores.count
    }

    var vitalityAgeStart: Int?
    var vitalityAgeEnd: Int?
    var streakRecord: Int = 0
    var previousYearScore: Int?
    var focusAreas: [String] = []
    var totalInsightsGenerated: Int = 0
    var totalDataPointsAnalyzed: Int = 0

    @State private var isShareSheetPresented = false
    @State private var shareImage: UIImage?

    var body: some View {
        ScrollView {
            VStack(spacing: DS.sectionSpacing) {
                AnnualReportHeroSection(
                    year: year,
                    overallScore: overallScore,
                    vitalityAgeStart: vitalityAgeStart,
                    vitalityAgeEnd: vitalityAgeEnd,
                    streakRecord: streakRecord
                )
                AnnualReportStatsSection(annualStats: annualStats)
                AnnualReportScoreSection(
                    year: year,
                    monthlyScores: monthlyScores,
                    overallScore: overallScore,
                    previousYearScore: previousYearScore
                )
                AnnualReportCategorySection(categoryScores: categoryScores)
                AnnualReportDiscoveriesSection(discoveries: discoveries)
                AnnualReportMilestonesSection(
                    records: records,
                    streakRecord: streakRecord,
                    totalInsightsGenerated: totalInsightsGenerated,
                    totalDataPointsAnalyzed: totalDataPointsAnalyzed
                )
                AnnualReportLookingAheadSection(
                    year: year,
                    categoryScores: categoryScores,
                    focusAreas: focusAreas
                )
            }
            .padding(.horizontal)
            .padding(.bottom, 40)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(Copy.Reports.yearInReview(year))
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    renderAndShare()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel(Copy.Reports.shareAnnualReport)
            }
        }
        .sheet(isPresented: $isShareSheetPresented) {
            if let image = shareImage {
                ShareSheetRepresentable(items: [image])
            }
        }
        .onAppear {
            AppAnalytics.shared.trackFeatureOpen(.annualReport)
        }
        .onDisappear {
            AppAnalytics.shared.trackFeatureClose(.annualReport)
        }
    }

    // MARK: - Sharing

    private func renderAndShare() {
        let reportCard = ShareableAnnualReportCard(
            year: year,
            overallScore: overallScore,
            totalActiveDays: annualStats.totalActiveDays,
            totalExerciseHours: annualStats.totalExerciseHours,
            averageSleepHours: annualStats.averageSleepHours,
            streakRecord: streakRecord
        )
        let renderer = ImageRenderer(content: reportCard)
        renderer.scale = UIScreen.main.scale
        guard let image = renderer.uiImage else { return }
        shareImage = image
        isShareSheetPresented = true
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        AnnualReportView(
            year: 2025,
            monthlyScores: [
                (month: 1, score: 68),
                (month: 2, score: 71),
                (month: 3, score: 65),
                (month: 4, score: 74),
                (month: 5, score: 78),
                (month: 6, score: 72),
                (month: 7, score: 80),
                (month: 8, score: 82),
                (month: 9, score: 77),
                (month: 10, score: 85),
                (month: 11, score: 79),
                (month: 12, score: 83)
            ],
            annualStats: AnnualStats(
                totalActiveDays: 287,
                totalExerciseHours: 342,
                totalDistanceKm: 1845,
                averageDailySteps: 8742,
                averageSleepHours: 7.2,
                sleepOver7HoursPercent: 68
            ),
            categoryScores: [
                AnnualCategoryScore(category: .heart, averageScore: 82, trend: .improving),
                AnnualCategoryScore(category: .sleep, averageScore: 71, trend: .stable),
                AnnualCategoryScore(category: .activity, averageScore: 78, trend: .improving),
                AnnualCategoryScore(category: .body, averageScore: 65, trend: .declining),
                AnnualCategoryScore(category: .respiratory, averageScore: 88, trend: .stable),
                AnnualCategoryScore(category: .mindfulness, averageScore: 55, trend: .improving),
                AnnualCategoryScore(category: .mobility, averageScore: 73, trend: .stable)
            ],
            discoveries: [
                AnnualDiscovery(
                    title: "Sleep-HRV Connection",
                    detail: "Your HRV improves by 12% on nights you sleep before 11pm",
                    category: .sleep,
                    month: 3
                ),
                AnnualDiscovery(
                    title: "Weekend Activity Gap",
                    detail: "Saturday step count averages 40% lower than weekday average",
                    category: .activity,
                    month: 5
                ),
                AnnualDiscovery(
                    title: "Resting HR Improvement",
                    detail: "Resting heart rate dropped 4 bpm since consistent cardio started in June",
                    category: .heart,
                    month: 8
                ),
                AnnualDiscovery(
                    title: "Stress Recovery Pattern",
                    detail: "Mindfulness sessions reduce next-day resting HR by an average of 3 bpm",
                    category: .mindfulness,
                    month: 10
                ),
                AnnualDiscovery(
                    title: "Seasonal Sleep Shift",
                    detail: "Average sleep duration increases by 35 min during winter months",
                    category: .sleep,
                    month: 11
                )
            ],
            records: [
                AnnualRecord(title: "Highest Score", detail: "Reached 92 on October 14", icon: "star.fill"),
                AnnualRecord(title: "Most Steps in a Day", detail: "24,381 steps on July 8", icon: "shoe.fill"),
                AnnualRecord(title: "Best Sleep Week", detail: "8.1 hrs average, week of Nov 3", icon: "moon.stars.fill"),
                AnnualRecord(title: "Longest Streak", detail: "47 consecutive active days", icon: "flame.fill")
            ],
            vitalityAgeStart: 34,
            vitalityAgeEnd: 31,
            streakRecord: 47,
            previousYearScore: 69,
            focusAreas: [
                "Improve mindfulness consistency with daily 5-minute sessions",
                "Address weekend activity gaps with scheduled Saturday movement",
                "Focus on body composition through strength training 3x/week"
            ],
            totalInsightsGenerated: 847,
            totalDataPointsAnalyzed: 142_350
        )
    }
}
