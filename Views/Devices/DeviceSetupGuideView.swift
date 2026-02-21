import SwiftUI

/// Step-by-step setup walkthrough for syncing a device with HealthKit
struct DeviceSetupGuideView: View {
    let device: SupportedDevice

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Setup Guide")
                .font(.subheadline.weight(.semibold))

            ForEach(Array(device.setupSteps.enumerated()), id: \.element.id) { index, step in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(index + 1)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(device.iconColor, in: Circle())

                    Text(step.instruction)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 12) {
                if let appStoreURL = device.appStoreURL {
                    Link(destination: appStoreURL) {
                        Label("Open App Store", systemImage: "arrow.down.app.fill")
                            .font(.subheadline.weight(.medium))
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    DeviceSetupGuideView(device: .garmin)
        .padding()
        .background(Color(.systemGroupedBackground))
}
