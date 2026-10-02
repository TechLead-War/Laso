import SwiftUI
import SwiftData

// MARK: - Entry Card (compact, for Home tab)

struct WeeklyReviewEntryCard: View {
    let viewModel: WeeklyReviewViewModel
    let onTap: () -> Void

    var body: some View {
        Group {
            if viewModel.review != nil {
                Button(action: onTap) {
                    HStack(spacing: DS.space2) {
                        Image(systemName: "calendar")
                        Text(Copy.Reports.WeeklyReviewView.title)
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Image(systemName: "arrow.up.right").font(.footnote)
                    }
                    .foregroundStyle(AppColour.primary)
                    .frame(minHeight: 44)
                    .padding(.horizontal, DS.screenPadding)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, DS.screenPadding)
                .accessibilityHint(Copy.Home.opensYourWeeklyReviewHint)
                .accessibilityIdentifier("home.weeklyReviewCard")
            }
        }
        .onAppear { viewModel.load() }
    }
}

// MARK: - Weekly Review

struct WeeklyReviewView: View {
    let viewModel: WeeklyReviewViewModel

    @State private var mirrorFullDay: Date?

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

                    highlightsSection(review)
                    mirrorWeekSection

                    // Progressive coach
                    if let coachPlan = review.coachPlan {
                        progressiveCoachSection(coachPlan)
                    }


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
        .background(AppColour.surfaceBase.ignoresSafeArea())
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
        .onChange(of: viewModel.sourceUpdatedAt) { _, _ in
            viewModel.load()
        }
        .onDisappear {
            AppAnalytics.shared.trackFeatureClose(.weeklyReview)
        }
    }

    // MARK: - Daily Mirror week strip

    /// The last seven days as faces. Only drawn when the week has at least one
    /// capture; a row of seven empty slots would read as a scolding. Tapping a
    /// face opens it full screen.
    @ViewBuilder
    private var mirrorWeekSection: some View {
        let store = MirrorPhotoStore.shared
        let days = (0..<7).map { Date.now.daysAgo(6 - $0) }
        let capturedCount = days.filter { store.hasPhoto(on: $0) }.count

        if capturedCount > 0 {
            VStack(alignment: .leading, spacing: DS.itemSpacing) {
                HStack {
                    Text(Copy.Mirror.weeklyStripTitle)
                        .font(DS.Typography.headline)
                    Spacer()
                    Text(Copy.Mirror.weeklyStripCount(capturedCount, days.count))
                        .font(DS.Typography.caption)
                        .foregroundStyle(AppColour.textSecondary)
                }

                HStack(spacing: DS.space1) {
                    ForEach(days, id: \.self) { day in
                        VStack(spacing: DS.space1) {
                            ZStack {
                                if let frame = MirrorPhotoFrame.forStoredDay(day, thumbnail: true) {
                                    Button {
                                        AppAnalytics.shared.trackBlockTap(
                                            title: "Open mirror photo",
                                            type: .mirrorPhotoOpened,
                                            screen: .weeklyReview,
                                            metadata: ["source": "weekly_strip"]
                                        )
                                        mirrorFullDay = day
                                    } label: {
                                        frame
                                    }
                                    .buttonStyle(.plain)
                                } else {
                                    Rectangle()
                                        .fill(AppColour.surfaceSubtle)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .aspectRatio(3.0 / 4.0, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))

                            Text(day.formatted(.dateTime.weekday(.narrow)))
                                .font(DS.Typography.caption2Medium)
                                .foregroundStyle(AppColour.textTertiary)
                        }
                    }
                }
            }
            .padding(DS.cardPadding)
            .cardStyle()
            .padding(.horizontal, DS.screenPadding)
            .fullScreenCover(isPresented: Binding(
                get: { mirrorFullDay != nil },
                set: { if !$0 { mirrorFullDay = nil } }
            )) {
                if let day = mirrorFullDay {
                    MirrorPhotoViewer(date: day) { mirrorFullDay = nil }
                }
            }
        }
    }

    // MARK: - Weekly summary

    private func weeklyAveragesSection(_ review: WeeklyReview) -> some View {
        VStack(spacing: DS.space3) {
            Text("Your week, in view")
                .font(.title3.weight(.medium))
                .foregroundStyle(AppColour.textPrimary)
            Text("Recent days count more in your weekly score.")
                .font(.subheadline)
                .foregroundStyle(AppColour.textSecondary)
                .multilineTextAlignment(.center)

            HealthScoreGauge(score: review.currentScore, label: "Weekly score",
                             tint: HealthScoreGauge.bandColor(review.currentScore))

            if let delta = viewModel.scoreDelta {
                Label(delta.formatted(.number.sign(strategy: .always())) + " points from last week",
                      systemImage: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.subheadline)
                    .foregroundStyle(delta >= 0 ? AppColour.primary : AppColour.warning)
            }

            HStack(spacing: 0) {
                weeklyStatColumn(label: "Wins", value: review.winCount.formatted(), color: AppColour.primary)
                Rectangle().fill(AppColour.borderLow).frame(width: 1, height: 36)
                weeklyStatColumn(label: "To watch", value: review.alertCount.formatted(),
                                 color: review.alertCount == 0 ? AppColour.textSecondary : AppColour.warning)
            }
            .padding(.vertical, DS.space4)
            .cardStyle()
        }
        .padding(.horizontal, DS.screenPadding)
    }

    private func weeklyStatColumn(label: String, value: String, color: Color) -> some View {
        VStack(spacing: DS.space1) {
            Text(value).font(.title2.weight(.medium).monospacedDigit()).foregroundStyle(color)
            Text(label).font(.footnote).foregroundStyle(AppColour.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func highlightsSection(_ review: WeeklyReview) -> some View {
        VStack(alignment: .leading, spacing: DS.space3) {
            Text("Weekly highlights").font(.headline)
            Text("Changes in recorded averages over the last 7 days compared with the previous 7 days.")
                .font(.footnote)
                .foregroundStyle(AppColour.textSecondary)

            VStack(spacing: 0) {
                ForEach(review.wins) { change in
                    highlightRow(change, isWin: true)
                        .onAppear { winsTracker.appeared() }
                        .onDisappear { winsTracker.disappeared() }
                }
                ForEach(review.watchOuts) { change in
                    highlightRow(change, isWin: false)
                        .onAppear { watchOutTracker.appeared() }
                        .onDisappear { watchOutTracker.disappeared() }
                }
                if review.wins.isEmpty && review.watchOuts.isEmpty {
                    Text("No notable changes to show. Comparisons need enough readings in both weeks.")
                        .font(.subheadline)
                        .foregroundStyle(AppColour.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(DS.cardPadding)
                }
            }
            .cardStyle()
        }
        .padding(.horizontal, DS.screenPadding)
    }

    private func highlightRow(_ change: DashboardViewModel.MetricChange, isWin: Bool) -> some View {
        NavigationLink(value: change.metric) {
            HStack(spacing: DS.space3) {
                Image(systemName: change.metric.category.systemImageName)
                    .font(.title3)
                    .foregroundStyle(isWin ? AppColour.primary : AppColour.warning)
                    .frame(width: 32)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: DS.space2) {
                        highlightLabel(change, isWin: isWin)
                        Spacer(minLength: 8)
                        highlightValue(change, isWin: isWin)
                    }
                    VStack(alignment: .leading, spacing: DS.space2) {
                        highlightLabel(change, isWin: isWin)
                        highlightValue(change, isWin: isWin)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColour.textTertiary)
            }
            .padding(DS.cardPadding)
            .frame(minHeight: 64)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("weeklyReview.highlight.\(change.metric.rawValue)")
    }

    private func highlightLabel(_ change: DashboardViewModel.MetricChange, isWin: Bool) -> some View {
        VStack(alignment: .leading, spacing: DS.space1) {
            Text(change.metric.displayName)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppColour.textPrimary)
            Text(isWin ? "Improving" : "Worth watching")
                .font(.caption)
                .foregroundStyle(AppColour.textSecondary)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func highlightValue(_ change: DashboardViewModel.MetricChange, isWin: Bool) -> some View {
        Label(abs(change.changePercent).formatted(.number.precision(.fractionLength(1))) + "%",
              systemImage: changeArrow(change.changePercent))
            .font(.subheadline.weight(.medium).monospacedDigit())
            .foregroundStyle(isWin ? AppColour.primary : AppColour.warning)
            .fixedSize()
            .accessibilityLabel("\(change.changePercent > 0 ? "Up" : "Down") \(abs(change.changePercent).formatted(.number.precision(.fractionLength(1)))) percent")
            .postHogMask()
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
