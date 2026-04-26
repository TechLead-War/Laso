import SwiftUI

struct VitalityDetailView: View {
    let scorer: VitalityScorer
    /// Pass 8 V (F45): freshness timestamp from the parent dashboard refresh.
    /// Drives a small "Updated …" caption at the top of the screen.
    var lastUpdated: Date? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var orbPhase: CGFloat = 0

    var body: some View {
        ScrollView {
            VStack(spacing: DS.sectionSpacing) {
                VitalityHeroSection(scorer: scorer, orbPhase: orbPhase)

                if !scorer.isFullyMature {
                    VitalityDataMaturityBanner(scorer: scorer)
                }

                if scorer.personalizationStatus != .buildingProfile && !scorer.componentAges.isEmpty {
                    VitalityMetricContributionSection(scorer: scorer)
                }

                if scorer.history.count >= 7 {
                    VitalityTrendSection(scorer: scorer)
                }

                if scorer.personalizationStatus != .buildingProfile && !scorer.topImprovementOpportunities.isEmpty {
                    VitalityImprovementSection(scorer: scorer)
                }

                VitalityMethodologySection()

                Text(Copy.Analysis.RiskDetail.disclaimer)
                    .font(DS.Typography.caption2)
                    .foregroundStyle(AppColour.textTertiary)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal)
                    .padding(.top, DS.space6)
                    .padding(.bottom, DS.space4)
            }
            .padding(.top, DS.space3)
            .padding(.bottom, DS.space6)
        }
        .background(AppColour.surfaceBase.ignoresSafeArea())
        .navigationTitle(Copy.Vitality.title)
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            AppAnalytics.shared.trackFeatureOpen(.vitalityDetail)
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 18).repeatForever(autoreverses: false)) {
                orbPhase = .pi * 2
            }
        }
        .onDisappear {
            AppAnalytics.shared.trackFeatureClose(.vitalityDetail)
        }
    }
}
