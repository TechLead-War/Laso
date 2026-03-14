import SwiftUI

struct LiveHeaderSection: View {
    let isStreaming: Bool
    let hasFreshData: Bool
    let isAging: Bool
    let isStale: Bool
    let hasAnyVitalData: Bool
    let primaryDevice: SupportedDevice?
    let currentHeartRate: Double?
    var headerTracker: SectionTracker

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Live")
                    .font(.largeTitle.bold())

                HStack(spacing: 6) {
                    Circle()
                        .fill(hasFreshData ? .green : (isAging ? .yellow : (isStale ? .orange : .gray)))
                        .frame(width: 8, height: 8)
                        .shadow(color: hasFreshData ? .green.opacity(0.6) : .clear, radius: 4)

                    Text(liveStatusLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if isStreaming && !hasFreshData {
                ProgressView()
                    .controlSize(.small)
                    .tint(.secondary)
            } else {
                Image(systemName: primaryDevice?.systemImageName ?? "waveform.path.ecg")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .symbolEffect(.pulse, isActive: hasFreshData)
            }
        }
        .padding(.horizontal)
        .padding(.top, 16)
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
