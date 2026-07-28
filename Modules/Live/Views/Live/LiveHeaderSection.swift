import SwiftUI

struct LiveHeaderSection: View {
    let isStreaming: Bool
    let hasFreshData: Bool
    let isAging: Bool
    let isStale: Bool
    let primaryDevice: SupportedDevice?
    var headerTracker: SectionTracker

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: DS.space1) {
                Text(Copy.Live.live)
                    .font(DS.Typography.largeTitle)

                HStack(spacing: 6) {
                    Circle()
                        .fill(hasFreshData ? AppColour.success : (isAging ? AppColour.warning : (isStale ? AppColour.danger : AppColour.stateDefault)))
                        .frame(width: 8, height: 8)
                        // glowTint, not a green bloom: a coloured zero-offset shadow
                        // reads as light on dark and as a smudge on light.
                        .shadow(color: hasFreshData ? AppColour.glowTint : .clear, radius: 4)

                    Text(liveStatusLabel)
                        .font(DS.Typography.caption)
                        .foregroundStyle(AppColour.textSecondary)
                }
            }

            Spacer()

            if isStreaming && !hasFreshData {
                ProgressView()
                    .controlSize(.small)
                    .tint(AppColour.textSecondary)
            } else {
                Image(systemName: primaryDevice?.systemImageName ?? "waveform.path.ecg")
                    .font(DS.Typography.title2)
                    .foregroundStyle(AppColour.textSecondary)
                    .symbolEffect(.pulse, isActive: hasFreshData)
            }
        }
        .padding(.horizontal)
        .padding(.top, DS.space4)
        .onAppear { headerTracker.appeared() }
        .onDisappear { headerTracker.disappeared() }
    }

    private var liveStatusLabel: String {
        if hasFreshData {
            return "Streaming"
        } else if isAging {
            return "Updating..."
        } else if isStreaming && primaryDevice == nil {
            return "Looking for a live source"
        } else if isStreaming {
            return "Refreshing..."
        } else if isStale {
            return primaryDevice == nil ? "Live source needed" : "Waiting for \(primaryDevice?.displayName ?? "device")"
        } else {
            return primaryDevice == nil ? "Wearable not detected" : "Connecting..."
        }
    }
}
