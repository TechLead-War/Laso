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
                            AppAnalytics.shared.trackBlockTap(
                                title: info.device.displayName,
                                type: .deviceRow,
                                screen: .connectedDevices,
                                metadata: [
                                    "device_id": info.device.rawValue,
                                    "device_connected": 1,
                                    "device_active": info.isActive ? 1 : 0,
                                    "metric_count": info.metricCount
                                ]
                            )
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
                            AppAnalytics.shared.trackBlockTap(
                                title: info.device.displayName,
                                type: .deviceRow,
                                screen: .connectedDevices,
                                metadata: [
                                    "device_id": info.device.rawValue,
                                    "device_connected": 1,
                                    "device_active": info.isActive ? 1 : 0,
                                    "metric_count": info.metricCount
                                ]
                            )
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
                        .simultaneousGesture(TapGesture().onEnded {
                            AppAnalytics.shared.trackBlockTap(
                                title: device.displayName,
                                type: .unconnectedDeviceRow,
                                screen: .connectedDevices,
                                metadata: [
                                    "device_id": device.rawValue,
                                    "device_connected": 0,
                                    "metric_count": device.supportedMetrics.count
                                ]
                            )
                        })
                    }
                } header: {
                    Text("Add More Devices")
                } footer: {
                    Text("Tap a device to see setup instructions for syncing with Apple Health.")
                }
            }
        }
        .accessibilityIdentifier("screen.connectedDevices")
        .navigationTitle("Connected Devices")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            AppAnalytics.shared.trackFeatureOpen(.connectedDevices, metadata: [
                "active_count": viewModel.activeDevices.count,
                "total_count": viewModel.activeDevices.count + viewModel.inactiveDevices.count
            ])
        }
        .onDisappear { AppAnalytics.shared.trackFeatureClose(.connectedDevices) }
        .refreshable {
            AppAnalytics.shared.trackPullToRefresh(screen: .connectedDevices)
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
