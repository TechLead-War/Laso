import SwiftUI

/// Daily focus actions from your coach — 3 concrete things to do today
struct CoachGoalsSection: View {
    let goals: [DashboardViewModel.CoachGoal]
    let daysOfData: Int
    let onTapGoal: (HealthMetric) -> Void

    var body: some View {
        if daysOfData < 7 {
            buildingProfileCard(daysRemaining: 7 - daysOfData)
        } else if !goals.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Your Coach")
                    .font(.headline)
                    .padding(.horizontal)

                ForEach(goals) { goal in
                    Button {
                        onTapGoal(goal.metric)
                    } label: {
                        goalCard(goal)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                }
            }
        }
    }

    private func goalCard(_ goal: DashboardViewModel.CoachGoal) -> some View {
        HStack(spacing: 12) {
            Image(systemName: goal.metric.systemImageName)
                .font(.title3)
                .foregroundStyle(goal.metric.category.color)
                .frame(width: DS.iconSize, height: DS.iconSize)
                .background(goal.metric.category.color.opacity(DS.badgeBg), in: RoundedRectangle(cornerRadius: DS.iconRadius))

            VStack(alignment: .leading, spacing: 3) {
                Text(goal.action)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(goal.reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 4)

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(DS.cardPadding)
        .cardStyle()
    }

    private func buildingProfileCard(daysRemaining: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: DS.iconSize)

            VStack(alignment: .leading, spacing: 2) {
                Text("Building your profile...")
                    .font(.subheadline.weight(.medium))
                Text("\(daysRemaining) more day\(daysRemaining == 1 ? "" : "s") until your coach can set goals")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(DS.cardPadding)
        .cardStyle()
        .padding(.horizontal)
    }
}
