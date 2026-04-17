import SwiftUI

// MARK: - Activation Progress Banner

/// Compact banner shown during the first 8 days. Displays calibration progress,
/// next milestone preview, and celebratory animations when milestones unlock.
struct ActivationProgressBanner: View {
    let state: ActivationSequenceManager.ActivationState
    let latestMilestone: ActivationSequenceManager.MilestoneEvent?
    let onDismissCelebration: () -> Void

    @State private var showCelebration = false

    var body: some View {
        if !state.isComplete {
            VStack(spacing: 0) {
                // Milestone celebration overlay
                if let milestone = latestMilestone, showCelebration {
                    celebrationCard(milestone)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Progress bar
                progressBar
            }
            .padding(.horizontal)
            .onAppear {
                AppAnalytics.shared.trackFeatureOpen(.home, metadata: ["subscreen": "activation_progress_banner", "current_day": state.currentDay, "progress_pct": Int(state.progressFraction * 100)])
            }
            .onChange(of: latestMilestone?.milestone.rawValue) { _, newValue in
                if let newValue {
                    AppAnalytics.shared.trackBlockTap(title: "Milestone Celebration Shown", type: .smartAction, screen: .home, metadata: ["source": "activation_progress", "milestone": newValue])
                    withAnimation(.spring(duration: 0.4)) {
                        showCelebration = true
                    }
                    // Auto-dismiss after 4 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            showCelebration = false
                            onDismissCelebration()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        VStack(spacing: 6) {
            HStack {
                Text(ActivationSequenceManager.progressDescription(state: state))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(state.progressFraction * 100))%")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.tint)
            }

            // Segmented progress
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(.systemFill))
                        .frame(height: 6)

                    // Progress fill
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * state.progressFraction, height: 6)
                        .animation(.spring(duration: 0.6), value: state.progressFraction)
                }
            }
            .frame(height: 6)

            // Milestone dots with connecting lines
            GeometryReader { geo in
                let dotSize: CGFloat = 6
                let totalDots: CGFloat = 8
                let totalGaps = totalDots - 1
                let availableWidth = geo.size.width - (dotSize * totalDots)
                let gapWidth = availableWidth / totalGaps

                ZStack(alignment: .leading) {
                    // Draw connecting lines first (behind dots)
                    ForEach(0..<7, id: \.self) { i in
                        let lineX = dotSize * CGFloat(i + 1) + gapWidth * CGFloat(i)
                        let filled = i < state.currentDay
                        RoundedRectangle(cornerRadius: 1)
                            .fill(filled ? Color.accentColor : Color(.systemFill))
                            .frame(width: gapWidth, height: 2)
                            .offset(x: lineX)
                    }

                    // Draw dots on top
                    ForEach(1...8, id: \.self) { day in
                        let dotX = dotSize * CGFloat(day - 1) + gapWidth * CGFloat(day - 1)
                        Circle()
                            .fill(day <= state.currentDay ? Color.accentColor : Color(.systemFill))
                            .frame(width: dotSize, height: dotSize)
                            .offset(x: dotX)
                    }
                }
                .frame(maxHeight: .infinity)
            }
            .frame(height: 6)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Celebration Card

    private func celebrationCard(_ event: ActivationSequenceManager.MilestoneEvent) -> some View {
        HStack(spacing: 12) {
            Image(systemName: event.milestone.icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(.tint, in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(event.milestone.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(event.milestone.detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Button {
                AppAnalytics.shared.trackBlockTap(title: "Milestone Celebration Dismissed", type: .smartAction, screen: .home, metadata: ["source": "activation_progress", "milestone": event.milestone.rawValue])
                withAnimation(.easeOut(duration: 0.2)) {
                    showCelebration = false
                    onDismissCelebration()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.background)
                .shadow(color: .accentColor.opacity(0.15), radius: 8, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(.tint.opacity(0.2), lineWidth: 1)
        )
        .padding(.bottom, 8)
    }
}

// MARK: - Ask Your Data Card

/// Compact card on Home that invites users to ask natural language questions.
struct AskYourDataCard: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: {
            AppAnalytics.shared.trackBlockTap(title: "Ask Your Data Card", type: .smartAction, screen: .home, metadata: ["source": "ask_your_data_card"])
            onTap()
        }) {
            HStack(spacing: 12) {
                Image(systemName: "text.bubble")
                    .font(.title3)
                    .foregroundStyle(.purple)
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Ask your data")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("\"How is my HRV trending?\"")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .italic()
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(.background, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(.purple.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
        .accessibilityIdentifier("home.askYourDataCard")
    }
}

#Preview {
    VStack(spacing: 16) {
        ActivationProgressBanner(
            state: ActivationSequenceManager.ActivationState(
                currentDay: 5,
                milestonesCompleted: [.firstBaseline, .firstComparison, .firstTrend, .firstPattern],
                installDate: Calendar.current.date(byAdding: .day, value: -4, to: Date())!,
                lastMilestoneDate: Date()
            ),
            latestMilestone: ActivationSequenceManager.MilestoneEvent(
                milestone: .firstCorrelation,
                unlockedAt: Date(),
                dataPointCount: 42
            ),
            onDismissCelebration: {}
        )

        AskYourDataCard(onTap: {})
    }
    .padding(.vertical)
    .background(Color(.systemGroupedBackground))
}
