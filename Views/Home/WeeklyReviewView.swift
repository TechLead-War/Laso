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
                    HStack(spacing: 12) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.blue)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Your Weekly Review")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)

                            HStack(spacing: 6) {
                                Text("Score \(review.currentScore)")
                                    .font(.caption.weight(.medium).monospacedDigit())
                                    .foregroundStyle(.secondary)

                                if let delta = viewModel.scoreDelta {
                                    Text(delta >= 0 ? "(+\(delta))" : "(\(delta))")
                                        .font(.caption.weight(.semibold).monospacedDigit())
                                        .foregroundStyle(delta >= 0 ? .green : .red)
                                }

                                if viewModel.winsCount > 0 {
                                    Text("·")
                                        .foregroundStyle(.tertiary)

                                    Text("\(viewModel.winsCount) win\(viewModel.winsCount == 1 ? "" : "s")")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            if let coachPlan = review.coachPlan {
                                Text("Coach target: \(formatSteps(coachPlan.currentDailyStepTarget))/day")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding()
                    .background(.background, in: RoundedRectangle(cornerRadius: DS.cardRadius))
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Weekly Review. Score \(review.currentScore). \(viewModel.winsCount) wins.")
                .accessibilityHint("Opens your weekly review")
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
                    VStack(spacing: 16) {
                        Spacer().frame(height: 40)
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("Not enough data yet")
                            .font(.title3.weight(.semibold))
                        Text("Keep syncing health data for a few days and check back.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                }
            }
            .padding(.vertical, 16)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Weekly Review")
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
                HStack(spacing: 4) {
                    Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption.weight(.bold))
                    Text(delta >= 0 ? "+\(delta) from last week" : "\(delta) from last week")
                        .font(.subheadline.weight(.medium))
                }
                .foregroundStyle(delta >= 0 ? .green : .red)
            } else {
                Text("First week — no comparison yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()
                .padding(.horizontal, 20)

            // Category score breakdown in a grid
            weeklyScoreGrid(review)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal)
        .background(DS.recoveryGradient(review.currentScore))
        .clipShape(RoundedRectangle(cornerRadius: DS.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: DS.cardRadius)
                .strokeBorder(DS.scoreColor(review.currentScore).opacity(DS.strokeAlpha), lineWidth: 0.5)
        )
        .padding(.horizontal)
    }

    private func weeklyScoreGrid(_ review: WeeklyReview) -> some View {
        let trend = review.scoreTrend
        return HStack(spacing: 0) {
            weeklyStatColumn(
                label: "Score",
                value: "\(review.currentScore)",
                color: DS.scoreColor(review.currentScore)
            )

            weeklyStatDivider

            weeklyStatColumn(
                label: "Trend",
                value: trend == .improving ? "Up" : trend == .declining ? "Down" : "Stable",
                color: trend == .improving ? .green : trend == .declining ? .red : .gray
            )

            weeklyStatDivider

            weeklyStatColumn(
                label: "Wins",
                value: "\(review.wins.count)",
                color: .green
            )

            weeklyStatDivider

            weeklyStatColumn(
                label: "Alerts",
                value: "\(review.watchOuts.count)",
                color: review.watchOuts.isEmpty ? .gray : .orange
            )
        }
    }

    private func weeklyStatColumn(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(color)
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
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
        VStack(alignment: .leading, spacing: 12) {
            Label("Highlights", systemImage: "calendar.day.timeline.left")
                .font(.headline)
                .padding(.horizontal)

            HStack(spacing: 12) {
                // Best day — top win
                if let topWin = review.wins.first {
                    dayHighlightCard(
                        label: "Best Metric",
                        metric: topWin.metric.displayName,
                        change: topWin.changePercent,
                        icon: "arrow.up.right.circle.fill",
                        color: .green
                    )
                }

                // Worst day — top decline
                if let topDecline = review.watchOuts.first {
                    dayHighlightCard(
                        label: "Needs Attention",
                        metric: topDecline.metric.displayName,
                        change: topDecline.changePercent,
                        icon: "arrow.down.right.circle.fill",
                        color: .orange
                    )
                }
            }
            .padding(.horizontal)
        }
    }

    private func dayHighlightCard(label: String, metric: String, change: Double, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(color)
                Text(label)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(color)
                    .textCase(.uppercase)
            }

            Text(metric)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)

            HStack(spacing: 3) {
                Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.caption2.weight(.bold))
                Text(String(format: "%.1f%%", abs(change)))
                    .font(.caption.weight(.semibold).monospacedDigit())
            }
            .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.cardPadding)
        .cardStyle(tint: color)
    }

    // MARK: - Personal Records / Wins

    private func personalRecordsSection(_ review: WeeklyReview) -> some View {
        Group {
            if !review.wins.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Label("This Week's Wins", systemImage: "trophy.fill")
                        .font(.headline)
                        .foregroundStyle(.green)
                        .padding(.horizontal)

                    VStack(spacing: 6) {
                        ForEach(review.wins) { change in
                            winRow(change)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.background, in: RoundedRectangle(cornerRadius: DS.cardRadius))
                .padding(.horizontal)
            }
        }
    }

    private func winRow(_ change: DashboardViewModel.MetricChange) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.body)
                .foregroundStyle(.green)

            Text(change.metric.displayName)
                .font(.subheadline.weight(.medium))

            Spacer()

            HStack(spacing: 3) {
                Image(systemName: "arrow.up.right")
                    .font(.caption2.weight(.bold))
                Text(String(format: "%.1f%%", abs(change.changePercent)))
                    .font(.caption.weight(.semibold).monospacedDigit())
            }
            .foregroundStyle(.green)
            .padding(.horizontal, DS.badgeH)
            .padding(.vertical, DS.badgeV)
            .background(.green.opacity(DS.badgeBg), in: Capsule())
        }
        .padding(.vertical, 4)
    }

    // MARK: - Top Insight of the Week

    private func topInsightSection(_ review: WeeklyReview) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Key Discovery", systemImage: "lightbulb.fill")
                .font(.headline)
                .foregroundStyle(.yellow)
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: 8) {
                if let topWin = review.wins.first {
                    Text("\(topWin.metric.displayName) improved by \(String(format: "%.1f%%", abs(topWin.changePercent))) this week.")
                        .font(.subheadline.weight(.medium))

                    Text("Consistency in \(topWin.metric.category.displayName) is paying off. Keep the momentum going into next week.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if let topDecline = review.watchOuts.first {
                    Text("\(topDecline.metric.displayName) dropped \(String(format: "%.1f%%", abs(topDecline.changePercent))) this week.")
                        .font(.subheadline.weight(.medium))

                    if let nudge = MetricChangeRow.nudgeFor(topDecline.metric) {
                        Text(nudge)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("A stable week across the board.")
                        .font(.subheadline.weight(.medium))

                    Text("No major changes detected. Consistency is a strength.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(DS.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle(tint: .yellow)
            .padding(.horizontal)
        }
    }

    // MARK: - Watch Out

    private func watchOutSection(_ review: WeeklyReview) -> some View {
        Group {
            if !review.watchOuts.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Watch Out", systemImage: "exclamationmark.triangle.fill")
                        .font(.headline)
                        .foregroundStyle(.orange)
                        .padding(.horizontal)

                    VStack(spacing: 6) {
                        ForEach(review.watchOuts) { change in
                            watchOutRow(change)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.background, in: RoundedRectangle(cornerRadius: DS.cardRadius))
                .padding(.horizontal)
            }
        }
    }

    private func watchOutRow(_ change: DashboardViewModel.MetricChange) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.body)
                    .foregroundStyle(.orange)

                Text(change.metric.displayName)
                    .font(.subheadline.weight(.medium))

                Spacer()

                HStack(spacing: 3) {
                    Image(systemName: "arrow.down.right")
                        .font(.caption2.weight(.bold))
                    Text(String(format: "%.1f%%", abs(change.changePercent)))
                        .font(.caption.weight(.semibold).monospacedDigit())
                }
                .foregroundStyle(.red)
                .padding(.horizontal, DS.badgeH)
                .padding(.vertical, DS.badgeV)
                .background(.red.opacity(DS.badgeBg), in: Capsule())
            }

            if let nudge = MetricChangeRow.nudgeFor(change.metric) {
                Text(nudge)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 30)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Progressive Coach

    private func progressiveCoachSection(_ plan: ProgressiveCoachPlan) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Progressive Coach", systemImage: "figure.walk.motion")
                .font(.headline)
                .foregroundStyle(.blue)
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Current target")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(formatSteps(plan.currentDailyStepTarget))/day")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                }

                HStack {
                    Text("Current average")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(formatSteps(plan.currentAverageDailySteps))/day")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                }

                HStack {
                    Text("Status")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(plan.adherence.displayName)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(adherenceColor(for: plan.adherence))
                        .padding(.horizontal, DS.badgeH)
                        .padding(.vertical, DS.badgeV)
                        .background(adherenceColor(for: plan.adherence).opacity(DS.badgeBg), in: Capsule())
                }

                Divider()

                HStack {
                    Text("Next week target")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(formatSteps(plan.nextDailyStepTarget))/day")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                    let deltaText = deltaLabel(plan.weeklyDelta)
                    if !deltaText.isEmpty {
                        Text(deltaText)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(plan.weeklyDelta >= 0 ? .green : .orange)
                    }
                }

                Text(plan.coachingMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(.background, in: RoundedRectangle(cornerRadius: DS.cardRadius))
            .padding(.horizontal)
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: DS.cardRadius))
        .padding(.horizontal)
    }

    // MARK: - Next Week Outlook

    private func nextWeekOutlookSection(_ review: WeeklyReview) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Next Week", systemImage: "arrow.right.circle.fill")
                .font(.headline)
                .foregroundStyle(.blue)
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: 8) {
                Text(nextWeekOutlookMessage(review))
                    .font(.subheadline)
                    .foregroundStyle(.primary)

                if let coachPlan = review.coachPlan {
                    HStack(spacing: 6) {
                        Image(systemName: "figure.walk")
                            .font(.caption)
                            .foregroundStyle(.blue)
                        Text("Step target: \(formatSteps(coachPlan.nextDailyStepTarget))/day")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.caption2)
                    Text("Powered by your personal health model")
                        .font(.caption2)
                }
                .foregroundStyle(.tertiary)
            }
            .padding(DS.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle(tint: .blue)
            .padding(.horizontal)
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

    private func adherenceColor(for status: CoachAdherenceStatus) -> Color {
        switch status {
        case .keepingUp: return .green
        case .plateauing: return .orange
        case .struggling: return .red
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
                    store: HealthDataStore(modelContainer: container)
                )
            )
        )
    }
}
