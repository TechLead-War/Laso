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
            HStack(spacing: 12) {
                Image(systemName: "gauge.with.dots.needle.67percent")
                    .font(.title3)
                    .foregroundStyle(.mint)
                    .frame(width: DS.iconSize, height: DS.iconSize)
                    .background(Color.mint.opacity(DS.badgeBg), in: RoundedRectangle(cornerRadius: DS.iconRadius))

                VStack(alignment: .leading, spacing: 2) {
                    Text(Copy.Explore.healthStates)
                        .font(.subheadline.weight(.semibold))
                    if let state = currentHealthState {
                        Text(Copy.Explore.healthStateDuration(label: state.label, days: state.daysInState))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(Copy.Explore.seeHealthStatePatterns)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(DS.cardPadding)
            .cardStyle()
        }
        .buttonStyle(.plain)
    }
}
