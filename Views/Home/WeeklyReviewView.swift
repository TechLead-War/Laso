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

// MARK: - Full Weekly Review Screen

struct WeeklyReviewView: View {
    let viewModel: WeeklyReviewViewModel

    // Section trackers
    @State private var scoreTracker = SectionTracker(section: .weeklyReviewScore, tab: .weeklyReview)
    @State private var winsTracker = SectionTracker(section: .weeklyReviewWins, tab: .weeklyReview)
    @State private var watchOutTracker = SectionTracker(section: .weeklyReviewWatchOut, tab: .weeklyReview)

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if let review = viewModel.review {
                    scoreSection(review)
                        .onAppear { scoreTracker.appeared() }
                        .onDisappear { scoreTracker.disappeared() }
                    if let coachPlan = review.coachPlan {
                        progressiveCoachSection(coachPlan)
                    }
                    winsSection(review)
                        .onAppear { winsTracker.appeared() }
                        .onDisappear { winsTracker.disappeared() }
                    watchOutSection(review)
                        .onAppear { watchOutTracker.appeared() }
                        .onDisappear { watchOutTracker.disappeared() }
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
                        Text("Wear your watch for a few days and check back.")
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

    // MARK: - Score Trend

    private func scoreSection(_ review: WeeklyReview) -> some View {
        VStack(spacing: 12) {
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
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal)
        .background(.background, in: RoundedRectangle(cornerRadius: DS.cardRadius))
        .padding(.horizontal)
    }

    // MARK: - Wins

    private func winsSection(_ review: WeeklyReview) -> some View {
        Group {
            if !review.wins.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Wins", systemImage: "trophy.fill")
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
        for: StoredDailySample.self, StoredSyncMetadata.self, StoredAnalysisSnapshot.self,
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
