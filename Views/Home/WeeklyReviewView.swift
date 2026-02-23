import SwiftUI

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
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding()
                    .background(.background, in: RoundedRectangle(cornerRadius: 16))
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
}

// MARK: - Full Weekly Review Screen

struct WeeklyReviewView: View {
    let viewModel: WeeklyReviewViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if let review = viewModel.review {
                    scoreSection(review)
                    winsSection(review)
                    watchOutSection(review)
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
        .onAppear {
            viewModel.load()
            AppAnalytics.shared.trackFeatureOpen(.weeklyReview)
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
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
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
                .background(.background, in: RoundedRectangle(cornerRadius: 16))
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
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.green.opacity(0.1), in: Capsule())
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
                .background(.background, in: RoundedRectangle(cornerRadius: 16))
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
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.red.opacity(0.1), in: Capsule())
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
}

#Preview {
    NavigationStack {
        WeeklyReviewView(
            viewModel: WeeklyReviewViewModel(
                dashboardViewModel: DashboardViewModel(
                    healthKitManager: HealthKitManager(),
                    analysisEngine: AnalysisEngine()
                )
            )
        )
    }
}
