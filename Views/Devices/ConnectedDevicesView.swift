import SwiftUI

/// Main device management screen showing connected, inactive, and discoverable devices
struct ConnectedDevicesView: View {
    let viewModel: ConnectedDevicesViewModel

    var body: some View {
        List {
            // Scan status + metric coverage
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.connectedCountText)
                            .font(.subheadline.weight(.semibold))
                        Text(viewModel.metricCoverageText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if viewModel.isScanning {
                        ProgressView()
                    }
                }
            }

            // Active Devices
            if !viewModel.activeDevices.isEmpty {
                Section("Active Devices") {
                    ForEach(viewModel.activeDevices) { info in
                        NavigationLink {
                            DeviceDetailView(device: info.device, deviceInfo: info)
                        } label: {
                            deviceRow(info: info)
                        }
                        .simultaneousGesture(TapGesture().onEnded {
                            AppAnalytics.shared.trackBlockTap(title: info.device.displayName, type: .deviceRow, screen: .connectedDevices)
                        })
                    }
                }
            }

            // Inactive Devices
            if !viewModel.inactiveDevices.isEmpty {
                Section {
                    ForEach(viewModel.inactiveDevices) { info in
                        NavigationLink {
                            DeviceDetailView(device: info.device, deviceInfo: info)
                        } label: {
                            deviceRow(info: info)
                        }
                        .simultaneousGesture(TapGesture().onEnded {
                            AppAnalytics.shared.trackBlockTap(title: info.device.displayName, type: .deviceRow, screen: .connectedDevices)
                        })
                    }
                } header: {
                    Text("Inactive Devices")
                } footer: {
                    Text("These devices have been detected but haven't synced data in the last 7 days.")
                }
            }

            // Add More Devices
            if !viewModel.unconnectedDevices.isEmpty {
                Section {
                    ForEach(viewModel.unconnectedDevices) { device in
                        NavigationLink {
                            DeviceDetailView(device: device, deviceInfo: nil)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: device.systemImageName)
                                    .font(.body)
                                    .foregroundStyle(device.iconColor)
                                    .frame(width: 28)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(device.displayName)
                                        .font(.subheadline.weight(.medium))
                                    Text("\(device.supportedMetrics.count) metrics available")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Add More Devices")
                } footer: {
                    Text("Tap a device to see setup instructions for syncing with Apple Health.")
                }
            }
        }
        .navigationTitle("Connected Devices")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { AppAnalytics.shared.trackFeatureOpen(.connectedDevices) }
        .onDisappear { AppAnalytics.shared.trackFeatureClose(.connectedDevices) }
        .refreshable {
            await viewModel.scan()
        }
        .task {
            if !viewModel.hasScanned {
                await viewModel.scan()
            }
        }
    }

    private func deviceRow(info: ConnectedDeviceInfo) -> some View {
        HStack(spacing: 12) {
            Image(systemName: info.device.systemImageName)
                .font(.body)
                .foregroundStyle(info.device.iconColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(info.device.displayName)
                    .font(.subheadline.weight(.medium))
                Text("\(info.metricCount) metrics \u{00B7} \(info.lastSyncText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Circle()
                .fill(info.isActive ? .green : .orange)
                .frame(width: 8, height: 8)
        }
    }
}

#Preview {
    NavigationStack {
        ConnectedDevicesView(
            viewModel: ConnectedDevicesViewModel(
                deviceSourceManager: DeviceSourceManager(healthStore: .init()),
                healthKitManager: HealthKitManager()
            )
        )
    }
}
