import SwiftUI

/// Main device management screen showing connected, inactive, and discoverable devices
struct ConnectedDevicesView: View {
    let viewModel: ConnectedDevicesViewModel

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: viewModel.statusSymbolName)
                            .font(.title2)
                            .foregroundStyle(viewModel.primaryDevice?.iconColor ?? .blue)
                            .frame(width: 36, height: 36)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(viewModel.statusHeadline)
                                .font(.headline)
                            Text(viewModel.statusDetail)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer()

                        if viewModel.isScanning {
                            ProgressView()
                        }
                    }

                    HStack(spacing: 12) {
                        summaryPill(
                            title: viewModel.connectedCountText,
                            detail: viewModel.activitySummaryText
                        )
                        summaryPill(
                            title: viewModel.metricCoverageText,
                            detail: "Coverage"
                        )
                        summaryPill(
                            title: viewModel.lastSyncSummaryText,
                            detail: "Last sync"
                        )
                    }
                }
            }
            .listRowInsets(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))

            if !viewModel.activeDevices.isEmpty {
                Section("Active Sources") {
                    ForEach(viewModel.activeDevices) { info in
                        NavigationLink {
                            DeviceDetailView(device: info.device, deviceInfo: info)
                                .onAppear {
                                    AppAnalytics.shared.trackBlockTap(
                                        title: info.presentationName,
                                        type: .deviceRow,
                                        screen: .connectedDevices,
                                        metadata: [
                                            "device_id": info.device.rawValue,
                                            "device_connected": 1,
                                            "device_active": info.isActive ? 1 : 0,
                                            "metric_count": info.metricCount
                                        ]
                                    )
                                }
                        } label: {
                            deviceRow(info: info)
                                .contentShape(Rectangle())
                        }
                    }
                }
            }

            if !viewModel.inactiveDevices.isEmpty {
                Section {
                    ForEach(viewModel.inactiveDevices) { info in
                        NavigationLink {
                            DeviceDetailView(device: info.device, deviceInfo: info)
                                .onAppear {
                                    AppAnalytics.shared.trackBlockTap(
                                        title: info.presentationName,
                                        type: .deviceRow,
                                        screen: .connectedDevices,
                                        metadata: [
                                            "device_id": info.device.rawValue,
                                            "device_connected": 1,
                                            "device_active": info.isActive ? 1 : 0,
                                            "metric_count": info.metricCount
                                        ]
                                    )
                                }
                        } label: {
                            deviceRow(info: info)
                                .contentShape(Rectangle())
                        }
                    }
                } header: {
                    Text("Connected But Inactive")
                } footer: {
                    Text("These sources were detected before, but they haven't written data to Apple Health in the last 7 days.")
                }
            }

            if !viewModel.unconnectedDevices.isEmpty {
                Section {
                    ForEach(viewModel.unconnectedDevices) { device in
                        NavigationLink {
                            DeviceDetailView(device: device, deviceInfo: nil)
                                .onAppear {
                                    AppAnalytics.shared.trackBlockTap(
                                        title: device.displayName,
                                        type: .unconnectedDeviceRow,
                                        screen: .connectedDevices,
                                        metadata: [
                                            "device_id": device.rawValue,
                                            "device_connected": 0
                                        ]
                                    )
                                }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: device.systemImageName)
                                    .font(.body)
                                    .foregroundStyle(device.iconColor)
                                    .frame(width: 28)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(device.displayName)
                                        .font(.subheadline.weight(.medium))
                                    Text(device.syncSummary)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                    }
                } header: {
                    Text(viewModel.availableSourcesTitle)
                } footer: {
                    Text(viewModel.availableSourcesFooter)
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

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(info.presentationName)
                        .font(.subheadline.weight(.medium))
                    if info.device == .generic {
                        Text("Detected")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.blue)
                            .padding(.horizontal, DS.space2)
                            .padding(.vertical, 3)
                            .background(Color.blue.opacity(0.12), in: Capsule())
                    } else {
                        Text(info.isActive ? "Active" : "Idle")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(info.isActive ? .green : .orange)
                            .padding(.horizontal, DS.space2)
                            .padding(.vertical, 3)
                            .background((info.isActive ? Color.green : Color.orange).opacity(0.12), in: Capsule())
                    }
                }

                Text(info.sourceDisplayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("\(info.metricCount) metrics \u{00B7} Last sync \(info.lastSyncText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private func summaryPill(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.space3)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
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
