import SwiftUI

struct VitalityDetailView: View {
    let scorer: VitalityScorer

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var orbPhase: CGFloat = 0
    @State private var isOnScreen = false

    /// The blob shape re-solves 81 points of trig on every frame this animation
    /// runs, so it may only run while the screen is actually in front of the user.
    /// `.inactive` is deliberately still animating: the screen stays visible behind
    /// system overlays, and stopping there would dim the glow in front of the user.
    private var orbAnimating: Bool { isOnScreen && scenePhase != .background }

    var body: some View {
        ScrollView {
            VStack(spacing: DS.sectionSpacing) {
                VitalityHeroSection(scorer: scorer, orbPhase: orbPhase, orbPaused: !orbAnimating)

                if !scorer.isFullyMature {
                    VitalityDataMaturityBanner(scorer: scorer)
                }

                if scorer.personalizationStatus != .buildingProfile && !scorer.componentAges.isEmpty {
                    VitalityMetricContributionSection(scorer: scorer)
                }

                if scorer.history.count >= VitalityScorer.minimumTrendDays {
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
            isOnScreen = true
        }
        .onDisappear {
            AppAnalytics.shared.trackFeatureClose(.vitalityDetail)
            isOnScreen = false
        }
        .onChange(of: orbAnimating) { _, animating in
            guard animating else {
                // A repeatForever animation only ends when its value is written
                // outside an animation.
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) { orbPhase = 0 }
                return
            }
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 18).repeatForever(autoreverses: false)) {
                orbPhase = .pi * 2
            }
        }
    }
}
