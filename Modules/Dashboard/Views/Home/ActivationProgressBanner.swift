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
            .padding(.horizontal, DS.screenPadding)
            .onAppear {
                AppAnalytics.shared.trackFeatureOpen(.home, metadata: ["subscreen": "activation_progress_banner", "current_day": state.currentDay, "progress_pct": Int(state.progressFraction * 100)])
            }
            .onChange(of: latestMilestone?.milestone.rawValue) { _, newValue in
                if let newValue {
                    AppAnalytics.shared.trackBlockTap(title: "Milestone Celebration Shown", type: .smartAction, screen: .home, metadata: ["source": "activation_progress", "milestone": newValue])
                    withAnimation(.spring(duration: 0.4)) {
                        showCelebration = true
                    }
                }
            }
            .task(id: showCelebration) {
                guard showCelebration else { return }
                try? await Task.sleep(for: .seconds(4))
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.3)) {
                    showCelebration = false
                    onDismissCelebration()
                }
            }
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        VStack(spacing: DS.space2) {
            HStack {
                Text(ActivationSequenceManager.progressDescription(state: state))
                    .font(DS.Typography.footnoteMedium)
                    .foregroundStyle(AppColour.textSecondary)
                Spacer()
                Text("\(Int(state.progressFraction * 100))%")
                    .font(DS.Typography.captionSemibold)
                    .foregroundStyle(.tint)
            }

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
                        RoundedRectangle(cornerRadius: DS.Radius.xs)
                            .fill(filled ? Color.accentColor : AppColour.borderLow)
                            .frame(width: gapWidth, height: 2)
                            .offset(x: lineX)
                    }

                    // Draw dots on top
                    ForEach(1...8, id: \.self) { day in
                        let dotX = dotSize * CGFloat(day - 1) + gapWidth * CGFloat(day - 1)
                        Circle()
                            .fill(day <= state.currentDay ? Color.accentColor : AppColour.borderLow)
                            .frame(width: dotSize, height: dotSize)
                            .offset(x: dotX)
                    }
                }
                .frame(maxHeight: .infinity)
            }
            .frame(height: 6)
        }
        .padding(.vertical, DS.space2)
        .padding(.horizontal, DS.space3)
        .glassChrome(in: RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    // MARK: - Celebration Card

    private func celebrationCard(_ event: ActivationSequenceManager.MilestoneEvent) -> some View {
        HStack(spacing: DS.space3) {
            Image(systemName: event.milestone.icon)
                .font(DS.Typography.bodySemibold)
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(.tint, in: RoundedRectangle(cornerRadius: DS.Radius.sm))

            VStack(alignment: .leading, spacing: DS.space1) {
                Text(event.milestone.title)
                    .font(DS.Typography.bodySemibold)
                    .foregroundStyle(AppColour.textPrimary)

                Text(event.milestone.detail)
                    .font(DS.Typography.footnote)
                    .foregroundStyle(AppColour.textSecondary)
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
                    .font(DS.Typography.captionSemibold)
                    .foregroundStyle(AppColour.textTertiary)
            }
            .accessibilityLabel("Dismiss milestone celebration")
            .accessibilityHint("Hides the milestone unlock card")
        }
        .padding(DS.space3)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .fill(AppColour.surfaceRaised)
                .shadow(color: .accentColor.opacity(0.15), radius: 8, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .strokeBorder(.tint.opacity(0.2), lineWidth: 1)
        )
        .padding(.bottom, DS.space2)
    }
}

// MARK: - Ask Your Data Card

/// Concierge-style prompt card on Home that invites users to ask natural
/// language questions. Shows a caption label above and a rotating italic
/// sample prompt inside a pill border for a calm, spacious feel.
struct AskYourDataCard: View {
    let onTap: () -> Void

    /// Pass 12 BE perf: cached current calendar. `samplePrompt` is read on
    /// every render of the home Ask-Your-Data card; per-render
    /// `Calendar.current` allocation is wasteful.
    private static let cal: Calendar = Calendar.current

    /// Deterministic prompt rotation. picks a sample question based on the
    /// current day so it shifts daily without flickering within a session.
    private var samplePrompt: String {
        let prompts = Copy.Home.AskYourData.conciergePrompts
        let day = Self.cal.ordinality(of: .day, in: .year, for: Date()) ?? 1
        return prompts[day % prompts.count]
    }

    var body: some View {
        Button(action: {
            AppAnalytics.shared.trackBlockTap(title: "Ask Your Data Card", type: .smartAction, screen: .home, metadata: ["source": "ask_your_data_card"])
            onTap()
        }) {
            VStack(alignment: .leading, spacing: DS.space2) {
                Text(Copy.Home.AskYourData.caption)
                    .font(DS.Typography.caption2Semibold)
                    .tracking(1.8)
                    .foregroundStyle(AppColour.textTertiary)

                HStack(spacing: DS.space3) {
                    Text(samplePrompt)
                        .font(DS.Typography.body)
                        .italic()
                        .foregroundStyle(AppColour.textSecondary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "arrow.right")
                        .font(DS.Typography.subheadlineSemibold)
                        .foregroundStyle(AppColour.textSecondary)
                }
                .padding(.vertical, DS.space4)
                .padding(.horizontal, DS.space5)
                .overlay(
                    Capsule()
                        .strokeBorder(AppColour.borderHigh, lineWidth: 1)
                )
            }
        }
        .buttonStyle(.dsPress)
        .padding(.horizontal, DS.screenPadding)
        .accessibilityIdentifier("home.askYourDataCard")
        .accessibilityLabel("\(Copy.Home.AskYourData.caption). \(samplePrompt)")
        .accessibilityHint("Opens Ask Your Data")
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
