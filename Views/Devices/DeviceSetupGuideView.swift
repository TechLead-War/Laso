import SwiftUI

/// Step-by-step setup walkthrough for syncing a device with HealthKit
struct DeviceSetupGuideView: View {
    let device: SupportedDevice

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(headerTitle)
                .font(.subheadline.weight(.semibold))

            Text(headerBody)
                .font(.caption)
                .foregroundStyle(.secondary)

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
                    .simultaneousGesture(TapGesture().onEnded {
                        AppAnalytics.shared.trackBlockTap(
                            title: "Open App Store — \(device.displayName)",
                            type: .appStoreLink,
                            screen: .deviceSetupGuide,
                            metadata: [
                                "device_id": device.rawValue,
                                "destination": "app_store"
                            ]
                        )
                    })
                }
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
        .onAppear {
            AppAnalytics.shared.trackFeatureOpen(.deviceSetupGuide, metadata: [
                "device": device.rawValue
            ])
        }
        .onDisappear {
            AppAnalytics.shared.trackFeatureClose(.deviceSetupGuide, metadata: [
                "device": device.rawValue
            ])
        }
    }

    private var headerTitle: String {
        switch device {
        case .appleWatch:
            return "Sync Through Apple Health"
        case .iPhone:
            return "Use iPhone Health Data"
        default:
            return "Connect Through Apple Health"
        }
    }

    private var headerBody: String {
        switch device {
        case .appleWatch:
            return "Use the Watch app and Apple Health permissions, then refresh Laso after the first watch samples sync."
        case .iPhone:
            return "Enable motion and fitness permissions so iPhone data can flow into Apple Health and Laso."
        default:
            return "Use \(device.companionAppName) to enable Apple Health sharing, then refresh Laso."
        }
    }
}

#Preview {
    DeviceSetupGuideView(device: .garmin)
        .padding()
        .background(Color(.systemGroupedBackground))
}
