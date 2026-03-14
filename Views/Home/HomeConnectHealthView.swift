import SwiftUI

struct HomeConnectHealthView: View {
    let deviceSourceManager: DeviceSourceManager
    let healthKitManager: HealthKitManager
    let onRefresh: () async -> Void

    var body: some View {
        VStack(spacing: 28) {
            Spacer().frame(height: 20)

            Image(systemName: "heart.text.clipboard")
                .font(.system(size: 56))
                .foregroundStyle(.tint)

            VStack(spacing: 8) {
                Text(Copy.Home.connectHealthData)
                    .font(.title3.weight(.semibold))

                Text(Copy.Home.connectHealthDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            // Supported devices — dynamic from SupportedDevice
            VStack(alignment: .leading, spacing: 14) {
                Text(Copy.Home.worksWith)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal)

                ForEach(SupportedDevice.discoverableDevices.prefix(6)) { device in
                    deviceRow(
                        icon: device.systemImageName,
                        name: device.displayName,
                        detail: device == .appleWatch
                            ? Copy.Home.syncsAutomatically
                            : Copy.Home.viaApp(device.companionAppName),
                        color: device.iconColor
                    )
                }
            }
            .padding()
            .background(.background, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)

            // How to connect
            VStack(alignment: .leading, spacing: 14) {
                Text(Copy.Home.howToConnect)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal)

                stepRow(number: 1, text: Copy.Home.connectStep1)
                stepRow(number: 2, text: Copy.Home.connectStep2)
                stepRow(number: 3, text: Copy.Home.connectStep3)
                stepRow(number: 4, text: Copy.Home.connectStep4)
            }
            .padding()
            .background(.background, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)

            // Manage Devices link
            NavigationLink {
                ConnectedDevicesView(
                    viewModel: ConnectedDevicesViewModel(
                        deviceSourceManager: deviceSourceManager,
                        healthKitManager: healthKitManager
                    )
                )
            } label: {
                Label(Copy.Home.manageDevices, systemImage: "gear")
                    .font(.subheadline.weight(.medium))
            }
            .buttonStyle(.bordered)
            .simultaneousGesture(TapGesture().onEnded {
                AppAnalytics.shared.trackBlockTap(
                    title: "Manage Devices",
                    type: .emptyStateManageDevices,
                    screen: .home,
                    metadata: [
                        "destination": "connected_devices",
                        "source": "empty_state"
                    ]
                )
            })

            Button {
                AppAnalytics.shared.trackBlockTap(
                    title: "Refresh",
                    type: .emptyStateRefresh,
                    screen: .home,
                    metadata: [
                        "source": "empty_state"
                    ]
                )
                Task { await onRefresh() }
            } label: {
                Label(Copy.Home.refresh, systemImage: "arrow.clockwise")
                    .font(.subheadline.weight(.medium))
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 4)

            Spacer()
        }
    }

    private func deviceRow(icon: String, name: String, detail: String, color: Color = .blue) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(color)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.subheadline.weight(.medium))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private func stepRow(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(.blue, in: Circle())
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
