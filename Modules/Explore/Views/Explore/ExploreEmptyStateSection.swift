import SwiftUI

struct ExploreEmptyStateSection: View {
    let hasAnyHealthData: Bool
    let isAuthorized: Bool
    var onConnectHealth: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                Image(systemName: hasAnyHealthData ? "chart.line.text.clipboard" : "heart.text.clipboard")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text(Copy.Explore.yourHealthScore)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(titleText)
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.primary)

                    Text(bodyText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            if !isAuthorized, let onConnectHealth {
                Button(action: onConnectHealth) {
                    Label("Connect Apple Health", systemImage: "heart.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
        }
        .padding(DS.space4)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    private var titleText: String {
        if hasAnyHealthData {
            return Copy.Explore.almostThere
        }
        return isAuthorized ? "Syncing your first insights" : Copy.Explore.noDataYet
    }

    private var bodyText: String {
        if hasAnyHealthData {
            return Copy.Explore.almostThereBody
        }
        if isAuthorized {
            return "Apple Health is already connected. Explore will populate after the next batch of imported samples is analyzed."
        }
        return Copy.Explore.noDataYetBody
    }
}
