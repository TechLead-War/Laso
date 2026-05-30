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
                            .font(DS.Typography.title2)
                            .foregroundStyle(viewModel.primaryDevice?.iconColor ?? AppColour.info)
                            .frame(width: 36, height: 36)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(viewModel.statusHeadline)
                                .font(DS.Typography.headline)
                            Text(viewModel.statusDetail)
                                .font(DS.Typography.subheadline)
                                .foregroundStyle(AppColour.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer()

                        if viewModel.isScanning {
                            ProgressView()
                                .accessibilityLabel(Copy.Devices.scanningForDevicesLabel)
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
                    Text(Copy.Devices.connectedButInactive)
                } footer: {
                    Text(Copy.Devices.theseSourcesWereDetectedBeforeBut)
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
                                    .font(DS.Typography.body)
                                    .foregroundStyle(device.iconColor)
                                    .frame(width: 28)

                                VStack(alignment: .leading, spacing: DS.space1) {
                                    Text(device.displayName)
                                        .font(DS.Typography.subheadlineMedium)
                                    Text(device.syncSummary)
                                        .font(DS.Typography.caption)
                                        .foregroundStyle(AppColour.textSecondary)
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
        .navigationTitle(Copy.Devices.connectedDevicesNavTitle)
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
                .font(DS.Typography.body)
                .foregroundStyle(info.device.iconColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(info.presentationName)
                        .font(DS.Typography.subheadlineMedium)
                    if info.device == .generic {
                        Text(Copy.Devices.detected)
                            .font(DS.Typography.caption2Semibold)
                            .foregroundStyle(AppColour.info)
                            .padding(.horizontal, DS.space2)
                            .padding(.vertical, DS.badgeV)
                            .background(AppColour.info.opacity(DS.badgeBg), in: Capsule())
                    } else {
                        Text(info.isActive ? "Active" : "Idle")
                            .font(DS.Typography.caption2Semibold)
                            .foregroundStyle(info.isActive ? AppColour.success : AppColour.warning)
                            .padding(.horizontal, DS.space2)
                            .padding(.vertical, DS.badgeV)
                            .background((info.isActive ? AppColour.success : AppColour.warning).opacity(DS.badgeBg), in: Capsule())
                    }
                }

                Text(info.sourceDisplayName)
                    .font(DS.Typography.caption)
                    .foregroundStyle(AppColour.textSecondary)

                Text(Copy.Devices.metricsAndLastSyncText(info.metricCount, info.lastSyncText))
                    .font(DS.Typography.caption)
                    .foregroundStyle(AppColour.textSecondary)
            }

            Spacer()
        }
    }

    private func summaryPill(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: DS.space1) {
            Text(title)
                .font(DS.Typography.subheadlineSemibold)
            Text(detail)
                .font(DS.Typography.caption)
                .foregroundStyle(AppColour.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.space3)
        .background(AppColour.surfaceRaised, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
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
