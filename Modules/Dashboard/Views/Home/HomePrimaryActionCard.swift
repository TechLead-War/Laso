import SwiftUI

struct HomePrimaryActionCard: View {
    let action: DashboardViewModel.SmartAction
    let overallScore: Int
    let recoveryStateRawValue: String
    let proofLine: String?
    let onTap: () -> Void

    init(
        action: DashboardViewModel.SmartAction,
        overallScore: Int,
        recoveryStateRawValue: String,
        proofLine: String? = nil,
        onTap: @escaping () -> Void
    ) {
        self.action = action
        self.overallScore = overallScore
        self.recoveryStateRawValue = recoveryStateRawValue
        self.proofLine = proofLine
        self.onTap = onTap
    }

    var body: some View {
        Button {
            AppAnalytics.shared.trackBlockTap(
                title: action.title,
                type: .homeDailyAction,
                screen: .home,
                metadata: [
                    "source": action.source,
                    "recovery_state": recoveryStateRawValue
                ]
            )
            onTap()
        } label: {
            VStack(alignment: .leading, spacing: DS.space2) {
                HStack(spacing: DS.space1) {
                    Image(systemName: "sparkle")
                        .font(DS.Typography.captionSemibold)
                        .foregroundStyle(AppColour.textSecondary)
                    Text(Copy.Home.todaysAction)
                        .font(DS.Typography.captionSemibold)
                        .foregroundStyle(AppColour.textSecondary)
                        .textCase(.uppercase)
                }

                HStack(spacing: DS.space3) {
                    Image(systemName: action.icon)
                        .font(DS.Typography.bodySemibold)
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(DS.scoreColor(overallScore), in: RoundedRectangle(cornerRadius: DS.Radius.sm))

                    VStack(alignment: .leading, spacing: DS.space1) {
                        Text(action.title)
                            .font(DS.Typography.bodySemibold)
                            .foregroundStyle(AppColour.textPrimary)
                            .lineLimit(2)

                        Text(action.subtitle)
                            .font(DS.Typography.callout)
                            .foregroundStyle(AppColour.textSecondary)
                            .lineLimit(2)

                        if let proof = proofLine {
                            Text(proof)
                                .font(DS.Typography.footnote)
                                .foregroundStyle(AppColour.textTertiary)
                                .lineLimit(2)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(DS.Typography.footnoteMedium)
                        .foregroundStyle(AppColour.textTertiary)
                }
            }
            .padding(DS.cardPadding)
            .cardStyle()
        }
        .buttonStyle(.dsPress)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Copy.Home.todaySActionLabel(action.title))
        .accessibilityValue(action.subtitle)
        .accessibilityHint(Copy.Home.opensGuidanceForTodaySRecommendedHint)
    }
}
