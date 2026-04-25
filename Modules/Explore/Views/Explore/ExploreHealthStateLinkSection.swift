import SwiftUI

struct ExploreHealthStateLinkSection: View {
    let currentHealthState: HealthState?
    let onTapped: () -> Void

    var body: some View {
        Button {
            AppAnalytics.shared.trackBlockTap(
                title: "Health States",
                type: .exploreHealthStateLink,
                screen: .explore,
                metadata: [
                    "has_current_state": currentHealthState != nil
                ]
            )
            onTapped()
        } label: {
            HStack(spacing: DS.itemSpacing) {
                Image(systemName: "gauge.with.dots.needle.67percent")
                    .font(DS.Typography.title3)
                    .foregroundStyle(AppColour.accent)
                    .frame(width: DS.iconSize, height: DS.iconSize)
                    .background(AppColour.accent.opacity(DS.badgeBg), in: RoundedRectangle(cornerRadius: DS.iconRadius))

                VStack(alignment: .leading, spacing: DS.space1) {
                    Text(Copy.Explore.healthStates)
                        .font(DS.Typography.subheadlineSemibold)
                    if let state = currentHealthState {
                        Text(Copy.Explore.healthStateDuration(label: state.label, days: state.daysInState))
                            .font(DS.Typography.caption)
                            .foregroundStyle(AppColour.textSecondary)
                    } else {
                        Text(Copy.Explore.seeHealthStatePatterns)
                            .font(DS.Typography.caption)
                            .foregroundStyle(AppColour.textSecondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(DS.Typography.captionSemibold)
                    .foregroundStyle(AppColour.textTertiary)
            }
            .padding(DS.cardPadding)
            .cardStyle()
        }
        .buttonStyle(.dsPress)
        .accessibilityIdentifier("explore.healthStateLink")
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Copy.Explore.healthStates)
        .accessibilityValue(currentHealthState.map { Copy.Explore.healthStateDuration(label: $0.label, days: $0.daysInState) } ?? Copy.Explore.seeHealthStatePatterns)
        .accessibilityHint("Opens the health states timeline")
    }
}
