import SwiftUI

// MARK: - Level Badge Card

/// Compact card for the Home tab showing user's current level and streaks.
/// Tappable to navigate to the full achievements view.
/// Uses `UserLevel` and `ActiveStreaks` from GamificationEngine.swift.
struct LevelBadgeCard: View {
    let level: UserLevel
    let totalDaysTracked: Int
    let progressToNext: Double
    let streaks: ActiveStreaks
    let onTap: () -> Void

    @State private var animatedProgress: Double = 0

    private var daysToNextLevel: Int? {
        guard let nextDays = level.nextLevelDays else { return nil }
        return max(nextDays - totalDaysTracked, 0)
    }

    private var completedDaysInLevel: Int {
        return totalDaysTracked - level.minDays
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Left: level icon
                levelIcon

                // Center: level name + progress
                centerColumn

                Spacer(minLength: 8)

                // Right: mini streak counters
                streakColumn

                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(DS.cardPadding)
            .cardStyle()
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
        .sensoryFeedback(.selection, trigger: animatedProgress)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint("View achievements and progress")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("home.levelBadgeCard")
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                animatedProgress = progressToNext
            }
        }
        .onChange(of: totalDaysTracked) {
            withAnimation(.easeOut(duration: 0.6)) {
                animatedProgress = progressToNext
            }
        }
    }

    // MARK: - Level Icon

    private var levelIcon: some View {
        ZStack {
            Circle()
                .fill(level.color.opacity(DS.badgeBg))
                .frame(width: DS.iconSize + 8, height: DS.iconSize + 8)

            Image(systemName: level.icon)
                .font(.body.weight(.bold))
                .foregroundStyle(level.color)
        }
    }

    // MARK: - Center Column

    private var centerColumn: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(level.displayName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(level.color.opacity(0.15))
                        .frame(height: 5)

                    Capsule()
                        .fill(level.color)
                        .frame(width: max(geo.size.width * animatedProgress, 5), height: 5)
                }
            }
            .frame(height: 5)

            // Days done + days to next level (endowed progress)
            if let daysRemaining = daysToNextLevel, let nextDays = level.nextLevelDays {
                let nextLevel = UserLevel.allCases.first { $0.minDays == nextDays }
                let almostThere = daysRemaining <= 3
                Text("\(completedDaysInLevel)d done \u{00B7} \(daysRemaining)d to \(nextLevel?.displayName ?? "Next")")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(almostThere ? level.color : .secondary)
            } else {
                Text("Max level reached")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(level.color)
            }
        }
        .frame(minWidth: 90)
    }

    // MARK: - Streak Column

    private var streakColumn: some View {
        VStack(alignment: .trailing, spacing: 4) {
            streakRow(icon: "figure.run", count: streaks.activityStreak, isHot: streaks.activityStreak >= 7)
            streakRow(icon: "moon.fill", count: streaks.sleepStreak, isHot: streaks.sleepStreak >= 7)
            streakRow(icon: "heart.fill", count: streaks.recoveryStreak, isHot: streaks.recoveryStreak >= 7)
        }
    }

    private func streakRow(icon: String, count: Int, isHot: Bool) -> some View {
        HStack(spacing: 4) {
            if isHot {
                Image(systemName: "flame.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }

            Image(systemName: icon)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            Text("\(count)")
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(.primary)
        }
    }

    // MARK: - Accessibility

    private var accessibilityDescription: String {
        var desc = "\(level.displayName) level, \(totalDaysTracked) days tracked"
        if let days = daysToNextLevel {
            desc += ", \(days) days to next level"
        }
        desc += ", activity streak \(streaks.activityStreak), sleep streak \(streaks.sleepStreak), recovery streak \(streaks.recoveryStreak)"
        return desc
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        LevelBadgeCard(
            level: .committed,
            totalDaysTracked: 42,
            progressToNext: 0.25,
            streaks: ActiveStreaks(
                activityStreak: 12, sleepStreak: 5, recoveryStreak: 8,
                checkInStreak: 3, masterStreak: 2,
                longestActivityStreak: 18, longestSleepStreak: 14,
                longestRecoveryStreak: 10, longestCheckInStreak: 7,
                longestMasterStreak: 5
            ),
            onTap: {}
        )

        LevelBadgeCard(
            level: .champion,
            totalDaysTracked: 195,
            progressToNext: 0.08,
            streaks: ActiveStreaks(
                activityStreak: 30, sleepStreak: 2, recoveryStreak: 15,
                checkInStreak: 10, masterStreak: 1,
                longestActivityStreak: 30, longestSleepStreak: 21,
                longestRecoveryStreak: 15, longestCheckInStreak: 12,
                longestMasterStreak: 8
            ),
            onTap: {}
        )
    }
    .padding(.vertical)
    .background(Color(.systemGroupedBackground))
}
