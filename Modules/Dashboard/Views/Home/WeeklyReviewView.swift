import SwiftUI
import SwiftData

// MARK: - Entry Card (compact, for Home tab)

struct WeeklyReviewEntryCard: View {
    let viewModel: WeeklyReviewViewModel
    let onTap: () -> Void

    var body: some View {
        Group {
            if let review = viewModel.review {
                Button(action: onTap) {
                    HStack(spacing: DS.space3) {
                        Image(systemName: "calendar.badge.clock")
                            .font(DS.Typography.mediumIcon)
                            .foregroundStyle(AppColour.info)

                        VStack(alignment: .leading, spacing: DS.space1) {
                            // No score, delta chip, or wins count here on purpose:
                            // that "weekly" score was today's daily score, the delta
                            // compared one arbitrary prior day, and "wins" counted
                            // any 2% move. The step target is the one honest line.
                            Text(Copy.Reports.WeeklyReviewView.title)
                                .font(DS.Typography.bodySemibold)
                                .foregroundStyle(AppColour.textPrimary)

                            if let coachPlan = review.coachPlan {
                                Text(Copy.Reports.WeeklyReviewView.coachTarget(formatSteps(coachPlan.currentDailyStepTarget)))
                                    .font(DS.Typography.caption)
                                    .foregroundStyle(AppColour.textSecondary)
                            }
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(DS.Typography.footnoteMedium)
                            .foregroundStyle(AppColour.textTertiary)
                    }
                    .padding()
                    .background(AppColour.surfaceRaised, in: RoundedRectangle(cornerRadius: DS.cardRadius))
                }
                .buttonStyle(.dsPress)
                .padding(.horizontal, DS.screenPadding)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Copy.Reports.WeeklyReviewView.title)
                .accessibilityHint(Copy.Home.opensYourWeeklyReviewHint)
                .accessibilityIdentifier("home.weeklyReviewCard")
            }
        }
        .onAppear {
            viewModel.load()
        }
    }

    private func formatSteps(_ value: Int) -> String {
        NumberFormatter.localizedString(from: NSNumber(value: value), number: .decimal)
    }
}

// MARK: - Full Weekly Review Screen (Whoop-style)

struct WeeklyReviewView: View {
    let viewModel: WeeklyReviewViewModel

    // Section trackers
    @State private var scoreTracker = SectionTracker(section: .weeklyReviewScore, tab: .weeklyReview)
    @State private var winsTracker = SectionTracker(section: .weeklyReviewWins, tab: .weeklyReview)
    @State private var watchOutTracker = SectionTracker(section: .weeklyReviewWatchOut, tab: .weeklyReview)

    /// First sentence of the recommendation for a declined metric. A full
    /// recommendation is several sentences and overruns these compact rows.
    private func nudgeFor(_ metric: HealthMetric) -> String? {
        let rec = RulesConfiguration.recommendation(for: metric, severity: .warning, trend: .declining)
        guard let dotIndex = rec.firstIndex(of: ".") else { return rec }
        return String(rec[rec.startIndex...dotIndex])
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let review = viewModel.review {
                    // Weekly averages hero
                    weeklyAveragesSection(review)
                        .onAppear { scoreTracker.appeared() }
                        .onDisappear { scoreTracker.disappeared() }

                    // Best & worst days
                    bestWorstDaysSection(review)

                    // Personal records / wins
                    personalRecordsSection(review)
                        .onAppear { winsTracker.appeared() }
                        .onDisappear { winsTracker.disappeared() }

                    // Top insight of the week
                    topInsightSection(review)

                    // Watch outs
                    watchOutSection(review)
                        .onAppear { watchOutTracker.appeared() }
                        .onDisappear { watchOutTracker.disappeared() }

                    // Progressive coach
                    if let coachPlan = review.coachPlan {
                        progressiveCoachSection(coachPlan)
                    }

                    // Next week outlook teaser
                    nextWeekOutlookSection(review)

                } else if viewModel.isLoading {
                    ProgressView()
                        .padding(.top, 40)
                } else {
                    VStack(spacing: DS.space4) {
                        Spacer().frame(height: 40)
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(DS.Typography.largeIcon)
                            .foregroundStyle(AppColour.textSecondary)
                        Text(Copy.Common.notEnoughData)
                            .font(DS.Typography.title3)
                        Text(Copy.Reports.WeeklyReviewView.keepSyncing)
                            .font(DS.Typography.body)
                            .foregroundStyle(AppColour.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, DS.space7)
                    }
                }
            }
            .padding(.vertical, DS.space4)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(Copy.Home.WeeklyReviewSections.navigationTitle)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let review = viewModel.review {
                    ShareButton(
                        cardType: .score(
                            score: review.currentScore,
                            scoreChange: viewModel.scoreDelta,
                            streakDays: SessionTracker.shared.streakDays
                        ),
                        screen: .weeklyReview
                    )
                }
            }
        }
        .onAppear {
            viewModel.load()
            AppAnalytics.shared.trackFeatureOpen(.weeklyReview, metadata: [
                "wins_count": viewModel.review?.wins.count ?? 0,
                "watchouts_count": viewModel.review?.watchOuts.count ?? 0
            ])
            AppAnalytics.shared.trackActivationMilestone(.firstWeeklyReview)
            AppAnalytics.shared.trackCoreAction(.viewedWeeklyReview, screen: .weeklyReview)
            AppAnalytics.shared.trackLastMeaningfulAction(action: "viewed_weekly_review", screen: .weeklyReview)
        }
        .onDisappear {
            AppAnalytics.shared.trackFeatureClose(.weeklyReview)
        }
    }

    // MARK: - Weekly Averages (Hero Section)

    private func weeklyAveragesSection(_ review: WeeklyReview) -> some View {
        VStack(spacing: 16) {
            // Score ring with gradient background
            HealthScoreRing(
                score: review.currentScore,
                label: "This Week",
                size: 120,
                lineWidth: 12
            )

            if let delta = viewModel.scoreDelta {
                HStack(spacing: DS.space1) {
                    Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(DS.Typography.calloutSemibold)
                    Text(delta >= 0 ? "+\(delta) from last week" : "\(delta) from last week")
                        .font(DS.Typography.bodyMedium)
                }
                .foregroundStyle(delta >= 0 ? AppColour.success : AppColour.danger)
            } else {
                Text(Copy.Reports.WeeklyReviewView.firstWeekNoComparison)
                    .font(DS.Typography.callout)
                    .foregroundStyle(AppColour.textSecondary)
            }

            Divider()
                .padding(.horizontal, DS.space5)

            // Category score breakdown in a grid
            weeklyScoreGrid(review)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.space5)
        .padding(.horizontal, DS.screenPadding)
        .background(DS.recoveryGradient(review.currentScore))
        .clipShape(RoundedRectangle(cornerRadius: DS.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: DS.cardRadius)
                .strokeBorder(DS.scoreColor(review.currentScore).opacity(DS.strokeAlpha), lineWidth: 0.5)
        )
        .padding(.horizontal, DS.screenPadding)
    }

    private func weeklyScoreGrid(_ review: WeeklyReview) -> some View {
        let trend = review.scoreTrend
        return HStack(spacing: 0) {
            weeklyStatColumn(
                label: "Score",
                value: "\(review.currentScore)",
                color: DS.scoreColor(review.currentScore)
            )

            // With no previous week there is nothing to compare against, so the
            // column is dropped instead of reporting a trend that was never measured.
            if review.previousScore != nil {
                weeklyStatDivider

                weeklyStatColumn(
                    label: "Trend",
                    value: trend == .improving ? "Up" : trend == .declining ? "Down" : "Stable",
                    color: trend == .improving ? AppColour.success : trend == .declining ? AppColour.danger : AppColour.textSecondary
                )
            }

            weeklyStatDivider

            weeklyStatColumn(
                label: "Wins",
                value: "\(review.winCount)",
                color: AppColour.success
            )

            weeklyStatDivider

            weeklyStatColumn(
                label: "Alerts",
                value: "\(review.alertCount)",
                color: review.alertCount == 0 ? AppColour.textSecondary : AppColour.warning
            )
        }
    }

    private func weeklyStatColumn(label: String, value: String, color: Color) -> some View {
        VStack(spacing: DS.space1) {
            Text(value)
                .font(DS.Typography.displayS)
                .foregroundStyle(color)
            Text(label)
                .font(DS.Typography.footnoteMedium)
                .foregroundStyle(AppColour.textSecondary)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
    }

    private var weeklyStatDivider: some View {
        Rectangle()
            .fill(.quaternary)
            .frame(width: 1, height: DS.dividerHeight)
    }

    // MARK: - Best & Worst Days

    private func bestWorstDaysSection(_ review: WeeklyReview) -> some View {
        VStack(alignment: .leading, spacing: DS.itemSpacing) {
            Label(Copy.Reports.WeeklyReviewView.highlightsLabel, systemImage: "calendar.day.timeline.left")
                .font(DS.Typography.title3)
                .padding(.horizontal, DS.screenPadding)

            HStack(alignment: .top, spacing: 12) {
                // Best day. top win
                if let topWin = review.wins.first {
                    dayHighlightCard(
                        label: "Best Metric",
                        metric: topWin.metric.displayName,
                        change: topWin.changePercent,
                        icon: "arrow.up.right.circle.fill",
                        color: AppColour.success
                    )
                }

                // Worst day. top decline
                if let topDecline = review.watchOuts.first {
                    dayHighlightCard(
                        label: "Worth Noticing",
                        metric: topDecline.metric.displayName,
                        change: topDecline.changePercent,
                        icon: "arrow.down.right.circle.fill",
                        color: AppColour.warning
                    )
                }
            }
            .padding(.horizontal, DS.screenPadding)
        }
    }

    private func dayHighlightCard(label: String, metric: String, change: Double, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: DS.space2) {
            HStack(spacing: DS.space1) {
                Image(systemName: icon)
                    .font(DS.Typography.title3)
                    .foregroundStyle(color)
                Text(label)
                    .font(DS.Typography.calloutSemibold)
                    .foregroundStyle(color)
                    .textCase(.uppercase)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Text(metric)
                .font(DS.Typography.bodySemibold)
                .lineLimit(2)
                .minimumScaleFactor(0.75)

            HStack(spacing: DS.space1) {
                Image(systemName: changeArrow(change))
                    .font(DS.Typography.captionSemibold)
                Text(String(format: "%.1f%%", abs(change)))
                    .font(DS.Typography.calloutSemibold.monospacedDigit())
            }
            .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(DS.cardPadding)
        .cardStyle(tint: color)
    }

    // MARK: - Personal Records / Wins

    private func personalRecordsSection(_ review: WeeklyReview) -> some View {
        Group {
            if !review.wins.isEmpty {
                VStack(alignment: .leading, spacing: DS.itemSpacing) {
                    Label(Copy.Reports.WeeklyReviewView.weeksWinsLabel, systemImage: "trophy.fill")
                        .font(DS.Typography.title3)
                        .foregroundStyle(AppColour.success)
                        .padding(.horizontal, DS.screenPadding)

                    VStack(spacing: 6) {
                        ForEach(review.wins) { change in
                            winRow(change)
                        }
                    }
                    .padding(.horizontal, DS.screenPadding)
                }
                .padding(.vertical, DS.space4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColour.surfaceRaised, in: RoundedRectangle(cornerRadius: DS.cardRadius))
                .padding(.horizontal, DS.screenPadding)
            }
        }
    }

    private func winRow(_ change: DashboardViewModel.MetricChange) -> some View {
        HStack(spacing: DS.space2) {
            Image(systemName: "checkmark.circle.fill")
                .font(DS.Typography.title3)
                .foregroundStyle(AppColour.success)

            Text(change.metric.displayName)
                .font(DS.Typography.bodyMedium)

            Spacer()

            HStack(spacing: DS.space1) {
                Image(systemName: changeArrow(change.changePercent))
                    .font(DS.Typography.captionSemibold)
                Text(String(format: "%.1f%%", abs(change.changePercent)))
                    .font(DS.Typography.calloutSemibold.monospacedDigit())
            }
            .foregroundStyle(AppColour.success)
            .padding(.horizontal, DS.badgeH)
            .padding(.vertical, DS.badgeV)
            .background(AppColour.success.opacity(DS.badgeBg), in: Capsule())
        }
        .padding(.vertical, DS.space1)
    }

    // MARK: - Top Insight of the Week

    private func topInsightSection(_ review: WeeklyReview) -> some View {
        VStack(alignment: .leading, spacing: DS.itemSpacing) {
            Label(Copy.Reports.WeeklyReviewView.keyDiscoveryLabel, systemImage: "lightbulb.fill")
                .font(DS.Typography.title3)
                .foregroundStyle(AppColour.scoreFair)
                .padding(.horizontal, DS.screenPadding)

            VStack(alignment: .leading, spacing: DS.space2) {
                if let topWin = review.wins.first {
                    Text("\(topWin.metric.displayName) improved by \(String(format: "%.1f%%", abs(topWin.changePercent))) this week.")
                        .font(DS.Typography.bodyMedium)

                    Text(Copy.Reports.WeeklyReviewView.consistencyPayingOff(topWin.metric.category.displayName))
                        .font(DS.Typography.callout)
                        .foregroundStyle(AppColour.textSecondary)
                } else if let topDecline = review.watchOuts.first {
                    Text("\(topDecline.metric.displayName) dropped \(String(format: "%.1f%%", abs(topDecline.changePercent))) this week.")
                        .font(DS.Typography.bodyMedium)

                    if let nudge = nudgeFor(topDecline.metric) {
                        Text(nudge)
                            .font(DS.Typography.callout)
                            .foregroundStyle(AppColour.textSecondary)
                    }
                } else {
                    Text(Copy.Reports.WeeklyReviewView.stableWeek)
                        .font(DS.Typography.bodyMedium)

                    Text(Copy.Reports.WeeklyReviewView.noMajorChanges)
                        .font(DS.Typography.callout)
                        .foregroundStyle(AppColour.textSecondary)
                }
            }
            .padding(DS.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle(tint: AppColour.scoreFair)
            .padding(.horizontal, DS.screenPadding)
        }
    }

    // MARK: - Watch Out

    private func watchOutSection(_ review: WeeklyReview) -> some View {
        Group {
            if !review.watchOuts.isEmpty {
                VStack(alignment: .leading, spacing: DS.itemSpacing) {
                    Label(Copy.Reports.WeeklyReviewView.watchOutLabel, systemImage: "exclamationmark.triangle.fill")
                        .font(DS.Typography.title3)
                        .foregroundStyle(AppColour.warning)
                        .padding(.horizontal, DS.screenPadding)

                    VStack(spacing: DS.space1) {
                        ForEach(review.watchOuts) { change in
                            watchOutRow(change)
                        }
                    }
                    .padding(.horizontal, DS.screenPadding)
                }
                .padding(.vertical, DS.space4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColour.surfaceRaised, in: RoundedRectangle(cornerRadius: DS.cardRadius))
                .padding(.horizontal, DS.screenPadding)
            }
        }
    }

    private func watchOutRow(_ change: DashboardViewModel.MetricChange) -> some View {
        VStack(alignment: .leading, spacing: DS.space1) {
            HStack(spacing: DS.space2) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(DS.Typography.title3)
                    .foregroundStyle(AppColour.warning)

                Text(change.metric.displayName)
                    .font(DS.Typography.bodyMedium)

                Spacer()

                HStack(spacing: DS.space1) {
                    Image(systemName: changeArrow(change.changePercent))
                        .font(DS.Typography.captionSemibold)
                    Text(String(format: "%.1f%%", abs(change.changePercent)))
                        .font(DS.Typography.footnoteMedium.monospacedDigit())
                }
                .foregroundStyle(AppColour.danger)
                .padding(.horizontal, DS.badgeH)
                .padding(.vertical, DS.badgeV)
                .background(AppColour.danger.opacity(DS.badgeBg), in: Capsule())
            }

            if let nudge = nudgeFor(change.metric) {
                Text(nudge)
                    .font(DS.Typography.caption)
                    .foregroundStyle(AppColour.textSecondary)
                    .padding(.leading, 30)
            }
        }
        .padding(.vertical, DS.space1)
    }

    // MARK: - Progressive Coach

    private func progressiveCoachSection(_ plan: ProgressiveCoachPlan) -> some View {
        VStack(alignment: .leading, spacing: DS.itemSpacing) {
            Label(Copy.Reports.WeeklyReviewView.progressiveCoachLabel, systemImage: "figure.walk.motion")
                .font(DS.Typography.title3)
                .foregroundStyle(AppColour.info)
                .padding(.horizontal, DS.screenPadding)

            VStack(alignment: .leading, spacing: DS.space2) {
                HStack {
                    Text(Copy.Reports.WeeklyReviewView.currentTarget)
                        .font(DS.Typography.body)
                        .foregroundStyle(AppColour.textSecondary)
                    Spacer()
                    Text(Copy.Home.dayText(formatSteps(plan.currentDailyStepTarget)))
                        .font(DS.Typography.bodySemibold.monospacedDigit())
                }

                HStack {
                    Text(Copy.Reports.WeeklyReviewView.currentAverage)
                        .font(DS.Typography.body)
                        .foregroundStyle(AppColour.textSecondary)
                    Spacer()
                    Text(Copy.Home.dayText2(formatSteps(plan.currentAverageDailySteps)))
                        .font(DS.Typography.bodySemibold.monospacedDigit())
                }

                HStack {
                    Text(Copy.Reports.WeeklyReviewView.status)
                        .font(DS.Typography.body)
                        .foregroundStyle(AppColour.textSecondary)
                    Spacer()
                    Text(plan.adherence.displayName)
                        .font(DS.Typography.footnoteMedium)
                        .foregroundStyle(adherenceColor(for: plan.adherence))
                        .padding(.horizontal, DS.badgeH)
                        .padding(.vertical, DS.badgeV)
                        .background(adherenceColor(for: plan.adherence).opacity(DS.badgeBg), in: Capsule())
                }

                Divider()

                HStack {
                    Text(Copy.Home.nextWeekTarget)
                        .font(DS.Typography.body)
                        .foregroundStyle(AppColour.textSecondary)
                    Spacer()
                    Text(Copy.Home.dayText3(formatSteps(plan.nextDailyStepTarget)))
                        .font(DS.Typography.bodySemibold.monospacedDigit())
                    let deltaText = deltaLabel(plan.weeklyDelta)
                    if !deltaText.isEmpty {
                        Text(deltaText)
                            .font(DS.Typography.footnoteMedium)
                            .foregroundStyle(plan.weeklyDelta >= 0 ? AppColour.success : AppColour.warning)
                    }
                }

                Text(plan.coachingMessage)
                    .font(DS.Typography.caption)
                    .foregroundStyle(AppColour.textSecondary)
            }
            .padding()
            .background(AppColour.surfaceRaised, in: RoundedRectangle(cornerRadius: DS.cardRadius))
            .padding(.horizontal, DS.screenPadding)
        }
        .padding(.vertical, DS.space4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColour.surfaceRaised, in: RoundedRectangle(cornerRadius: DS.cardRadius))
        .padding(.horizontal, DS.screenPadding)
    }

    // MARK: - Next Week Outlook

    private func nextWeekOutlookSection(_ review: WeeklyReview) -> some View {
        VStack(alignment: .leading, spacing: DS.itemSpacing) {
            Label(Copy.Reports.WeeklyReviewView.nextWeekLabel, systemImage: "arrow.right.circle.fill")
                .font(DS.Typography.title3)
                .foregroundStyle(AppColour.info)
                .padding(.horizontal, DS.screenPadding)

            VStack(alignment: .leading, spacing: DS.space2) {
                Text(nextWeekOutlookMessage(review))
                    .font(DS.Typography.body)
                    .foregroundStyle(AppColour.textPrimary)

                if let coachPlan = review.coachPlan {
                    HStack(spacing: DS.space1) {
                        Image(systemName: "figure.walk")
                            .font(DS.Typography.caption)
                            .foregroundStyle(AppColour.info)
                        Text(Copy.Reports.WeeklyReviewView.stepTarget(formatSteps(coachPlan.nextDailyStepTarget)))
                            .font(DS.Typography.footnoteMedium)
                            .foregroundStyle(AppColour.textSecondary)
                    }
                }

                HStack(spacing: DS.space1) {
                    Image(systemName: "sparkles")
                        .font(DS.Typography.caption)
                    Text(Copy.Reports.WeeklyReviewView.poweredByModel)
                        .font(DS.Typography.caption)
                }
                .foregroundStyle(AppColour.textTertiary)
            }
            .padding(DS.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle(tint: AppColour.info)
            .padding(.horizontal, DS.screenPadding)
        }
    }

    private func nextWeekOutlookMessage(_ review: WeeklyReview) -> String {
        let hasWins = !review.wins.isEmpty
        let hasDeclines = !review.watchOuts.isEmpty

        switch (hasWins, hasDeclines) {
        case (true, false):
            return "Strong momentum heading into next week. Keep building on your wins and maintain consistency."
        case (true, true):
            if let topDecline = review.watchOuts.first {
                return "Good progress overall. Focus on \(topDecline.metric.displayName) next week to keep improving."
            }
            return "Mixed signals this week. Focus on consistency next week."
        case (false, true):
            return "A challenging week. Small, consistent improvements next week can make a big difference."
        case (false, false):
            return "A steady week. Next week is a chance to push for new improvements."
        }
    }

    // MARK: - Helpers

    /// `changePercent` keeps the real sign of the movement, and whether that
    /// movement is good is already decided by `HealthMetric.higherIsBetter`
    /// upstream. The arrow follows the sign so a metric like resting heart rate
    /// never points up in one section and down in another for the same number.
    private func changeArrow(_ changePercent: Double) -> String {
        changePercent >= 0 ? "arrow.up.right" : "arrow.down.right"
    }

    private func adherenceColor(for status: CoachAdherenceStatus) -> Color {
        switch status {
        case .keepingUp: return AppColour.success
        case .plateauing: return AppColour.warning
        case .struggling: return AppColour.danger
        }
    }

    private func deltaLabel(_ delta: Int) -> String {
        guard delta != 0 else { return "" }
        let sign = delta > 0 ? "+" : "-"
        return "(\(sign)\(formatSteps(abs(delta))))"
    }

    private func formatSteps(_ value: Int) -> String {
        NumberFormatter.localizedString(from: NSNumber(value: value), number: .decimal)
    }
}

#Preview {
    let container = try! ModelContainer(
        for: StoredDailySample.self, StoredSyncMetadata.self, StoredAnalysisSnapshot.self, StoredDailyStrain.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    NavigationStack {
        WeeklyReviewView(
            viewModel: WeeklyReviewViewModel(
                dashboardViewModel: DashboardViewModel(
                    healthKitManager: HealthKitManager(),
                    analysisEngine: AnalysisEngine(),
                    store: HealthDataStore(modelContainer: container),
                    housekeepingService: DashboardHousekeepingService(
                        persistenceManager: PersistenceManager(),
                        analytics: AppAnalytics.shared,
                        sessionTracker: SessionTracker.shared
                    )
                )
            )
        )
    }
}
