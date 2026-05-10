import SwiftUI

/// Proactive daily narrative card. Uses Apple's on-device Foundation Models
/// (iOS 26+) to generate a short paragraph that tells the user what today
/// looks like for their body, grounded in their actual HealthKit signals.
///
/// Silent on older OSes and on any generation failure — no error state is
/// surfaced to the user. If narrative is nil the card renders `EmptyView`
/// so the Home stack collapses cleanly.
struct DailyNarrativeCard: View {
    let signals: DailyNarrativeSignals

    @State private var narrative: String?
    @State private var isLoading = false
    @State private var didAttempt = false

    var body: some View {
        Group {
            if let narrative, !narrative.isEmpty {
                narrativeBody(narrative)
            } else if isLoading {
                loadingBody
            } else {
                EmptyView()
            }
        }
        .task {
            await loadNarrative()
        }
    }

    // MARK: - Loaded Body

    private func narrativeBody(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: DS.space2) {
            HStack(spacing: DS.space1) {
                Image(systemName: "sparkles")
                    .font(DS.Typography.captionSemibold)
                    .foregroundStyle(.tint)
                Text(Copy.Home.Cards.forYouToday)
                    .font(DS.Typography.captionSemibold)
                    .tracking(0.8)
                    .foregroundStyle(AppColour.textSecondary)
            }
            Text(text)
                .font(DS.Typography.bodyMedium)
                .foregroundStyle(AppColour.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .postHogMask()
        }
        .padding(.horizontal, DS.space5)
        .padding(.vertical, DS.space3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColour.surfaceRaised, in: RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
        .padding(.horizontal, DS.screenPadding)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Loading Body

    private var loadingBody: some View {
        HStack(spacing: DS.space2) {
            ProgressView()
                .controlSize(.small)
            Text(Copy.Home.Cards.readingTodaysSignals)
                .font(DS.Typography.callout)
                .foregroundStyle(AppColour.textSecondary)
        }
        .padding(.horizontal, DS.space5)
        .padding(.vertical, DS.space3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColour.surfaceRaised, in: RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
        .padding(.horizontal, DS.screenPadding)
    }

    // MARK: - Generation

    private func loadNarrative() async {
        guard !didAttempt else { return }
        didAttempt = true

        // Affirmative gate — flip OFF in Firebase Remote Config to silence the
        // narrative card without rebuilding (e.g. on-device LLM regression).
        guard RemoteConfigManager.shared.aiNarrativeEnabled else { return }

        #if canImport(FoundationModels)
        guard #available(iOS 26, *) else { return }
        isLoading = true
        let result = await DailyNarrativeEngine.shared.narrativeForToday(signals: signals)
        withAnimation(.easeInOut(duration: 0.25)) {
            narrative = result
            isLoading = false
        }
        if result != nil {
            AppAnalytics.shared.trackCoreAction(.viewedInsight, screen: .home)
        }
        #endif
    }
}
