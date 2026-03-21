import SwiftUI

struct HomeConnectHealthView: View {
    let deviceSourceManager: DeviceSourceManager
    let healthKitManager: HealthKitManager
    let onRefresh: () async -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 20)

            Image(systemName: heroIconName)
                .font(.system(size: 56))
                .foregroundStyle(heroIconColor)

            VStack(spacing: 8) {
                Text(titleText)
                    .font(.title3.weight(.semibold))

                Text(statusDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            statusCard

            progressCard

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
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 24)

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

            Spacer()
        }
    }

    private var primarySource: ConnectedDeviceInfo? {
        deviceSourceManager.connectedDevices.first
    }

    private var primaryDevice: SupportedDevice? {
        primarySource?.device
    }

    private var heroIconName: String {
        primaryDevice?.systemImageName ?? "heart.text.square.fill"
    }

    private var heroIconColor: Color {
        primaryDevice?.iconColor ?? .blue
    }

    private var titleText: String {
        primarySource == nil ? "Apple Health is connected" : "Your health source is connected"
    }

    private var primarySourceName: String {
        primarySource?.sourceName ?? "Apple Health"
    }

    private var statusDescription: String {
        if let progress = healthKitManager.syncProgress {
            if let primaryDevice {
                return "\(primaryDevice.displayName) is connected. Laso is currently \(progress.phase.title.lowercased()) for your first dashboard."
            }
            return "Apple Health is connected. Laso is currently \(progress.phase.title.lowercased()) for your first dashboard."
        }

        if let firstSource = primarySource {
            return "\(firstSource.device.displayName) is already syncing through \(firstSource.sourceName). Laso is waiting for the first imported samples to finish your Home dashboard."
        }

        return "Apple Health is authorized. As soon as the next batch of samples arrives, Laso will build your dashboard automatically."
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Connected Source")
                .font(.subheadline.weight(.semibold))

            HStack(spacing: 12) {
                Image(systemName: heroIconName)
                    .font(.title3)
                    .foregroundStyle(heroIconColor)
                    .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 3) {
                    Text(primaryDevice?.displayName ?? "Apple Health")
                        .font(.subheadline.weight(.semibold))
                    Text(dataFlowText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(deviceSourceManager.connectedDevices.isEmpty ? "Authorized" : "Connected")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.12), in: Capsule())
            }

            HStack(spacing: 12) {
                statCard(
                    title: deviceSourceManager.connectedDevices.isEmpty ? "Pending first sync" : "\(deviceSourceManager.connectedDevices.count)",
                    subtitle: deviceSourceManager.connectedDevices.isEmpty ? "Source detection" : "Connected sources"
                )
                statCard(
                    title: "\(deviceSourceManager.totalTrackedMetrics)",
                    subtitle: "Tracked metrics"
                )
                statCard(
                    title: deviceSourceManager.connectedDevices.first?.lastSyncText ?? "Soon",
                    subtitle: "Latest sync"
                )
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    @ViewBuilder
    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(healthKitManager.syncProgress == nil ? "What Happens Next" : "Import Status")
                .font(.subheadline.weight(.semibold))

            if let progress = healthKitManager.syncProgress {
                ProgressView(
                    value: Double(progress.metricsCompleted),
                    total: Double(max(progress.totalMetrics, 1))
                )

                Text(progress.phase.title)
                    .font(.subheadline.weight(.medium))

                Text("\(progress.metricsCompleted) of \(progress.totalMetrics) metrics checked")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                expectationRow(
                    title: primarySource == nil ? "Keep Apple Health up to date" : "Keep the source syncing",
                    detail: nextStepDetail
                )
                expectationRow(
                    title: "Refresh after the next sync",
                    detail: "Pull to refresh here any time you want Laso to re-check for new samples."
                )
                expectationRow(
                    title: "Your dashboard fills in automatically",
                    detail: "Recovery, trends, and device coverage appear as soon as the first imported data lands."
                )
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    private func statCard(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private var dataFlowText: String {
        if primarySource == nil {
            return "Apple Health \u{2192} Laso"
        }
        return "\(primarySourceName) \u{2192} Apple Health \u{2192} Laso"
    }

    private var nextStepDetail: String {
        if let primaryDevice {
            return "Wear \(primaryDevice.displayName) or open \(primarySourceName) so the latest samples reach Apple Health."
        }
        return "New steps, sleep, workouts, and other samples will appear here after the next Apple Health sync."
    }

    private func expectationRow(title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(heroIconColor)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
