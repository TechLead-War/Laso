import SwiftUI

struct HomePrimaryActionCard: View {
    let action: DashboardViewModel.SmartAction
    let overallScore: Int
    let recoveryStateRawValue: String

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
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 4) {
                    Image(systemName: "sparkle")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                    Text(Copy.Home.todaysAction)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                }

                HStack(spacing: 12) {
                    Image(systemName: action.icon)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(DS.scoreColor(overallScore), in: RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(action.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)

                        Text(action.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Spacer()
                }
            }
            .padding(DS.cardPadding)
            .cardStyle()
        }
        .buttonStyle(.plain)
    }
}
