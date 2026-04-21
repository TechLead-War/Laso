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
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 4) {
                    Image(systemName: "sparkle")
                        .font(.system(size: 13.2).weight(.bold))
                        .foregroundStyle(.secondary)
                    Text(Copy.Home.todaysAction)
                        .font(.system(size: 14.4).weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                }

                HStack(spacing: 12) {
                    Image(systemName: action.icon)
                        .font(.system(size: 24).weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(DS.scoreColor(overallScore), in: RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(action.title)
                            .font(.system(size: 18).weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)

                        Text(action.subtitle)
                            .font(.system(size: 14.4))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)

                        if let proof = proofLine {
                            Text(proof)
                                .font(.system(size: 13.2))
                                .foregroundStyle(.tertiary)
                                .lineLimit(2)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13.2).weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(DS.cardPadding)
            .cardStyle()
        }
        .buttonStyle(.plain)
    }
}
