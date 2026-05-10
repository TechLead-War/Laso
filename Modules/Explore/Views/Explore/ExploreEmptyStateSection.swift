import SwiftUI

struct ExploreEmptyStateSection: View {
    let hasAnyHealthData: Bool
    let isAuthorized: Bool
    var onConnectHealth: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: DS.space4) {
            HStack(spacing: DS.space4) {
                Image(systemName: hasAnyHealthData ? "chart.line.text.clipboard" : "heart.text.clipboard")
                    .font(DS.Typography.largeIcon)
                    .foregroundStyle(AppColour.textSecondary)

                VStack(alignment: .leading, spacing: DS.space1) {
                    Text(Copy.Explore.yourHealthScore)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(AppColour.textSecondary)

                    Text(titleText)
                        .font(DS.Typography.title3)
                        .foregroundStyle(AppColour.textPrimary)

                    Text(bodyText)
                        .font(DS.Typography.caption)
                        .foregroundStyle(AppColour.textSecondary)
                }

                Spacer()
            }

            if !isAuthorized, let onConnectHealth {
                Button(action: onConnectHealth) {
                    Label(Copy.Explore.emptyStateConnectButton, systemImage: "heart.fill")
                        .font(DS.Typography.subheadlineSemibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.dsPrimary)
            }
        }
        .padding(DS.space4)
        .background(AppColour.surfaceRaised, in: RoundedRectangle(cornerRadius: DS.Radius.xl))
    }

    private var titleText: String {
        if hasAnyHealthData {
            return Copy.Explore.almostThere
        }
        return isAuthorized ? Copy.Explore.emptyStateSyncing : Copy.Explore.noDataYet
    }

    private var bodyText: String {
        if hasAnyHealthData {
            return Copy.Explore.almostThereBody
        }
        if isAuthorized {
            return Copy.Explore.emptyStateSyncingBody
        }
        return Copy.Explore.noDataYetBody
    }
}
