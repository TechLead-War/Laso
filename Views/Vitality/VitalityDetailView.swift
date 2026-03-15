import SwiftUI

struct VitalityDetailView: View {
    let scorer: VitalityScorer

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
            }
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
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
