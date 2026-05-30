import SwiftUI

/// Step-by-step setup walkthrough for syncing a device with HealthKit
struct DeviceSetupGuideView: View {
    let device: SupportedDevice

    var body: some View {
        VStack(alignment: .leading, spacing: DS.space4) {
            Text(headerTitle)
                .font(DS.Typography.subheadlineSemibold)

            Text(headerBody)
                .font(DS.Typography.caption)
                .foregroundStyle(AppColour.textSecondary)

            ForEach(Array(device.setupSteps.enumerated()), id: \.element.id) { index, step in
                HStack(alignment: .top, spacing: DS.itemSpacing) {
                    Text(Copy.Devices.xText(index + 1))
                        .font(DS.Typography.captionSemibold)
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(device.iconColor, in: Circle())

                    Text(step.instruction)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(AppColour.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 12) {
                if let appStoreURL = device.appStoreURL {
                    Link(destination: appStoreURL) {
                        Label(Copy.Devices.openAppStoreLabel, systemImage: "arrow.down.app.fill")
                            .font(DS.Typography.subheadlineMedium)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding()
        .background(AppColour.surfaceRaised, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
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
            return "Most third-party devices need \(device.companionAppName) to enable Apple Health sharing before Laso can detect them."
        }
    }
}

#Preview {
    DeviceSetupGuideView(device: .garmin)
        .padding()
        .background(AppColour.surfaceBase)
}
