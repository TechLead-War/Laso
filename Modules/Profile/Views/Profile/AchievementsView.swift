import SwiftUI

// MARK: - Level

/// Progression level used by AchievementsView's hero section.
enum Level: Int, CaseIterable, Comparable {
    case bronze = 0
    case silver = 1
    case gold = 2
    case platinum = 3
    case diamond = 4

    static func < (lhs: Level, rhs: Level) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var name: String {
        switch self {
        case .bronze:   "Bronze"
        case .silver:   "Silver"
        case .gold:     "Gold"
        case .platinum: "Platinum"
        case .diamond:  "Diamond"
        }
    }

    var color: Color {
        switch self {
        case .bronze:   AppColour.achievementBronze
        case .silver:   AppColour.achievementSilver
        case .gold:     AppColour.achievementGold
        case .platinum: AppColour.achievementPlatinum
        case .diamond:  AppColour.achievementDiamond
        }
    }

    var gradient: LinearGradient {
        LinearGradient(colors: [color, color.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var icon: String {
        switch self {
        case .bronze:   "leaf.fill"
        case .silver:   "shield.fill"
        case .gold:     "star.fill"
        case .platinum: "bolt.fill"
        case .diamond:  "diamond.fill"
        }
    }

    var next: Level? {
        Self.allCases.first(where: { $0.rawValue == rawValue + 1 })
    }

    var minDays: Int {
        switch self {
        case .bronze: 0; case .silver: 7; case .gold: 30; case .platinum: 90; case .diamond: 180
        }
    }
}

// MARK: - LevelInfo

struct LevelInfo {
    let level: Level
    let progressToNext: Double
    let totalDaysTracked: Int
    let daysToNextLevel: Int?

    static func from(daysTracked: Int) -> LevelInfo {
        let currentLevel = Level.allCases.last(where: { daysTracked >= $0.minDays }) ?? .bronze
        let progress: Double
        let daysToNext: Int?
        if let next = currentLevel.next {
            let range = next.minDays - currentLevel.minDays
            let done = daysTracked - currentLevel.minDays
            progress = range > 0 ? min(Double(done) / Double(range), 1.0) : 1.0
            daysToNext = max(next.minDays - daysTracked, 0)
        } else {
            progress = 1.0
            daysToNext = nil
        }
        return LevelInfo(level: currentLevel, progressToNext: progress, totalDaysTracked: daysTracked, daysToNextLevel: daysToNext)
    }
}

// MARK: - StreakInfo

struct StreakInfo: Identifiable {
    let id: String
    let name: String
    let icon: String
    let current: Int
    let best: Int

    var isHot: Bool { current >= 7 }
}

// MARK: - Achievement Definition

/// A single achievement that can be unlocked through health tracking milestones.
struct AchievementItem: Identifiable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let requirement: String
    let category: AchievementCategory
    var unlockDate: Date?

    var isUnlocked: Bool { unlockDate != nil }

    enum AchievementCategory: String, CaseIterable {
        case streak = "Streaks"
        case milestone = "Milestones"
        case consistency = "Consistency"
        case exploration = "Exploration"

        var color: Color {
            switch self {
            case .streak: return .orange
            case .milestone: return .blue
            case .consistency: return .green
            case .exploration: return .purple
            }
        }

        var icon: String {
            switch self {
            case .streak: return "flame.fill"
            case .milestone: return "flag.fill"
            case .consistency: return "checkmark.seal.fill"
            case .exploration: return "safari.fill"
            }
        }
    }
}

// MARK: - Achievements Stats

/// Aggregate statistics for the achievements view header.
struct AchievementsStats {
    let totalDaysTracked: Int
    let totalUnlocked: Int
    let totalAchievements: Int
    let longestStreakEver: Int
}

// MARK: - Achievements View

/// Full gamification view showing level progress, active streaks, and achievement collection.
struct AchievementsView: View {
    let levelInfo: LevelInfo
    let streaks: [StreakInfo]
    let achievements: [AchievementItem]
    let stats: AchievementsStats

    @State private var ringProgress: Double = 0
    @State private var selectedCategory: AchievementItem.AchievementCategory?

    private let gridColumns = [
        GridItem(.flexible(), spacing: DS.itemSpacing),
        GridItem(.flexible(), spacing: DS.itemSpacing)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: DS.sectionSpacing) {
                // Hero: level badge
                heroSection

                // Active streaks
                streaksSection

                // Stats row
                statsRow

                // Achievements grid
                achievementsSection
            }
            .padding(.bottom, DS.space7)
        }
        .scrollIndicators(.hidden)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Your Progress")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            AppAnalytics.shared.trackFeatureOpen(.achievements)
            withAnimation(.easeOut(duration: 1.0).delay(0.2)) {
                ringProgress = levelInfo.progressToNext
            }
        }
        .onDisappear {
            AppAnalytics.shared.trackFeatureClose(.achievements)
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: 16) {
            // Level progress ring
            ZStack {
                // Track
                Circle()
                    .stroke(levelInfo.level.color.opacity(0.15), lineWidth: 10)
                    .frame(width: 120, height: 120)

                // Fill
                Circle()
                    .trim(from: 0, to: ringProgress)
                    .stroke(
                        levelInfo.level.gradient,
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))

                // Center icon
                VStack(spacing: 2) {
                    Image(systemName: levelInfo.level.icon)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(levelInfo.level.color)

                    if levelInfo.level != .diamond {
                        Text("\(Int(levelInfo.progressToNext * 100))%")
                            .font(.caption2.weight(.bold).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .sensoryFeedback(.impact(flexibility: .soft), trigger: ringProgress)

            // Level name
            Text(levelInfo.level.name)
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)

            // Days tracked subtitle
            Text("\(levelInfo.totalDaysTracked) days tracked")
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)

            // Next level info
            if let daysRemaining = levelInfo.daysToNextLevel, let next = levelInfo.level.next {
                HStack(spacing: 6) {
                    Image(systemName: next.icon)
                        .font(DS.Typography.captionSemibold)
                        .foregroundStyle(next.color)
                    Text("\(daysRemaining) days to \(next.name)")
                        .font(DS.Typography.captionSemibold)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(next.color.opacity(0.08), in: Capsule())
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(DS.Typography.captionSemibold)
                        .foregroundStyle(levelInfo.level.color)
                    Text("Highest level achieved")
                        .font(DS.Typography.captionSemibold)
                        .foregroundStyle(levelInfo.level.color)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(levelInfo.level.color.opacity(0.08), in: Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.space6)
        .padding(.horizontal, DS.cardPadding)
        .background(.background, in: RoundedRectangle(cornerRadius: DS.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: DS.cardRadius)
                .strokeBorder(levelInfo.level.color.opacity(DS.strokeAlpha * 2), lineWidth: 1)
        )
        .shadow(color: levelInfo.level.color.opacity(0.1), radius: 12, y: 4)
        .padding(.horizontal)
        .padding(.top, DS.space2)
    }

    // MARK: - Streaks Section

    private var streaksSection: some View {
        VStack(alignment: .leading, spacing: DS.itemSpacing) {
            Text("Active Streaks")
                .font(DS.Typography.headline)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.itemSpacing) {
                    ForEach(streaks) { streak in
                        streakCard(streak)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func streakCard(_ streak: StreakInfo) -> some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(streak.isHot ? Color.orange.opacity(0.12) : Color(.systemGray5))
                    .frame(width: 48, height: 48)

                Image(systemName: streak.icon)
                    .font(DS.Typography.title3)
                    .foregroundStyle(streak.isHot ? .orange : .secondary)

                // Animated indicator for hot streaks
                if streak.isHot {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.orange)
                        .offset(x: 16, y: -16)
                        .symbolEffect(.pulse, options: .repeating)
                }
            }

            VStack(spacing: 2) {
                Text(streak.name)
                    .font(DS.Typography.caption2Semibold)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Text("\(streak.current)")
                    .font(.title3.weight(.bold).monospacedDigit())
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())

                Text("days")
                    .font(DS.Typography.caption2Medium)
                    .foregroundStyle(.tertiary)
            }

            // All-time best
            HStack(spacing: 2) {
                Image(systemName: "trophy.fill")
                    .font(DS.Typography.caption2)
                    .foregroundStyle(.yellow)
                Text("\(streak.best)")
                    .font(.caption2.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 100)
        .padding(.vertical, 14)
        .background(.background, in: RoundedRectangle(cornerRadius: DS.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: DS.cardRadius)
                .strokeBorder(
                    streak.isHot ? Color.orange.opacity(DS.strokeAlpha * 3) : Color.primary.opacity(0.06),
                    lineWidth: 0.5
                )
        )
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 0) {
            statItem(value: "\(stats.totalDaysTracked)", label: "Days", icon: "calendar")

            Divider()
                .frame(height: DS.dividerHeight)

            statItem(value: "\(stats.totalUnlocked)/\(stats.totalAchievements)", label: "Unlocked", icon: "trophy.fill")

            Divider()
                .frame(height: DS.dividerHeight)

            statItem(value: "\(stats.longestStreakEver)", label: "Best Streak", icon: "flame.fill")
        }
        .padding(.vertical, DS.cardPadding)
        .background(.background, in: RoundedRectangle(cornerRadius: DS.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: DS.cardRadius)
                .strokeBorder(.primary.opacity(0.06), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
        .padding(.horizontal)
    }

    private func statItem(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(DS.Typography.caption2)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(.primary)

            Text(label)
                .font(DS.Typography.caption2Medium)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Achievements Section

    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: DS.itemSpacing) {
            HStack {
                Text("Achievements")
                    .font(DS.Typography.headline)

                Spacer()

                Text("\(sortedAchievements.filter(\.isUnlocked).count) of \(sortedAchievements.count)")
                    .font(DS.Typography.captionMedium)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            // Category filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    categoryPill(nil, label: "All")

                    ForEach(AchievementItem.AchievementCategory.allCases, id: \.rawValue) { category in
                        categoryPill(category, label: category.rawValue)
                    }
                }
                .padding(.horizontal)
            }

            // Grid
            LazyVGrid(columns: gridColumns, spacing: DS.itemSpacing) {
                ForEach(filteredAchievements) { achievement in
                    achievementCard(achievement)
                }
            }
            .padding(.horizontal)
        }
    }

    private func categoryPill(_ category: AchievementItem.AchievementCategory?, label: String) -> some View {
        let isSelected = selectedCategory == category
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedCategory = category
            }
            AppAnalytics.shared.trackBlockTap(
                title: label,
                type: .achievementCategoryFilter,
                screen: .achievements,
                metadata: ["category": category?.rawValue ?? "all"]
            )
        } label: {
            Text(label)
                .font(DS.Typography.captionSemibold)
                .foregroundStyle(isSelected ? .white : .secondary)
                .padding(.horizontal, DS.space3)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color(.systemGray5), in: Capsule())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
    }

    // Sort: unlocked (by date, newest first), then locked
    private var sortedAchievements: [AchievementItem] {
        let unlocked = achievements.filter(\.isUnlocked).sorted { ($0.unlockDate ?? .distantPast) > ($1.unlockDate ?? .distantPast) }
        let locked = achievements.filter { !$0.isUnlocked }
        return unlocked + locked
    }

    private var filteredAchievements: [AchievementItem] {
        guard let category = selectedCategory else { return sortedAchievements }
        return sortedAchievements.filter { $0.category == category }
    }

    private func achievementCard(_ achievement: AchievementItem) -> some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(
                        achievement.isUnlocked
                            ? achievement.category.color.opacity(DS.badgeBg)
                            : Color(.systemGray5)
                    )
                    .frame(width: 48, height: 48)

                if achievement.isUnlocked {
                    Image(systemName: achievement.icon)
                        .font(DS.Typography.title3)
                        .foregroundStyle(achievement.category.color)
                } else {
                    Image(systemName: "lock.fill")
                        .font(DS.Typography.bodyMedium)
                        .foregroundStyle(Color(.systemGray3))
                }
            }

            VStack(spacing: 3) {
                Text(achievement.title)
                    .font(DS.Typography.captionSemibold)
                    .foregroundStyle(achievement.isUnlocked ? .primary : .secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                if achievement.isUnlocked, let date = achievement.unlockDate {
                    Text(date, format: .dateTime.month(.abbreviated).day())
                        .font(DS.Typography.caption2Medium)
                        .foregroundStyle(.tertiary)
                } else {
                    Text(achievement.requirement)
                        .font(DS.Typography.caption2Medium)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, DS.space2)
        .background(.background, in: RoundedRectangle(cornerRadius: DS.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: DS.cardRadius)
                .strokeBorder(
                    achievement.isUnlocked
                        ? achievement.category.color.opacity(DS.strokeAlpha * 2)
                        : Color.primary.opacity(0.06),
                    lineWidth: 0.5
                )
        )
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
        .opacity(achievement.isUnlocked ? 1.0 : 0.7)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            achievement.isUnlocked
                ? "\(achievement.title), unlocked"
                : "\(achievement.title), locked, \(achievement.requirement)"
        )
    }
}

// MARK: - Preview

#Preview {
    let now = Date()
    let cal = Calendar.current

    NavigationStack {
        AchievementsView(
            levelInfo: LevelInfo.from(daysTracked: 45),
            streaks: [
                StreakInfo(id: "activity", name: "Activity", icon: "figure.run", current: 12, best: 18),
                StreakInfo(id: "sleep", name: "Sleep", icon: "moon.fill", current: 5, best: 14),
                StreakInfo(id: "recovery", name: "Recovery", icon: "heart.fill", current: 8, best: 10),
                StreakInfo(id: "mindfulness", name: "Mindful", icon: "brain.head.profile", current: 3, best: 7),
                StreakInfo(id: "hrv", name: "HRV", icon: "waveform.path.ecg", current: 15, best: 20)
            ],
            achievements: [
                AchievementItem(id: "first_day", title: "First Steps", description: "Track your first day", icon: "figure.walk", requirement: "Track 1 day", category: .milestone, unlockDate: cal.date(byAdding: .day, value: -44, to: now)),
                AchievementItem(id: "week_streak", title: "Week Warrior", description: "7-day streak", icon: "flame.fill", requirement: "7-day streak", category: .streak, unlockDate: cal.date(byAdding: .day, value: -37, to: now)),
                AchievementItem(id: "month_tracked", title: "Dedicated", description: "30 days tracked", icon: "calendar.badge.checkmark", requirement: "Track 30 days", category: .milestone, unlockDate: cal.date(byAdding: .day, value: -14, to: now)),
                AchievementItem(id: "all_categories", title: "Well-Rounded", description: "Data in all categories", icon: "circle.grid.3x3.fill", requirement: "All 7 categories", category: .exploration, unlockDate: cal.date(byAdding: .day, value: -10, to: now)),
                AchievementItem(id: "night_owl", title: "Sleep Scholar", description: "14-day sleep streak", icon: "moon.stars.fill", requirement: "14-day sleep streak", category: .streak),
                AchievementItem(id: "iron_heart", title: "Iron Heart", description: "30-day activity streak", icon: "heart.circle.fill", requirement: "30-day activity streak", category: .streak),
                AchievementItem(id: "century", title: "Century Club", description: "100 days tracked", icon: "star.circle.fill", requirement: "Track 100 days", category: .milestone),
                AchievementItem(id: "perfect_week", title: "Perfect Week", description: "All goals met for 7 days", icon: "checkmark.seal.fill", requirement: "7 perfect days", category: .consistency),
                AchievementItem(id: "explorer", title: "Deep Dive", description: "View every metric detail", icon: "magnifyingglass.circle.fill", requirement: "View all metrics", category: .exploration),
                AchievementItem(id: "steady", title: "Rock Steady", description: "Score above 70 for 14 days", icon: "chart.line.uptrend.xyaxis.circle.fill", requirement: "Score 70+ for 14 days", category: .consistency)
            ],
            stats: AchievementsStats(
                totalDaysTracked: 45,
                totalUnlocked: 4,
                totalAchievements: 10,
                longestStreakEver: 18
            )
        )
    }
}
