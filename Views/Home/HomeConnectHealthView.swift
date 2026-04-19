import SwiftUI

/// Calm empty state for when no health data has reached Laso yet. Deliberately
/// shows one icon, one message, one primary action. Secondary device management
/// lives in Settings, not here.
struct HomeConnectHealthView: View {
    let deviceSourceManager: DeviceSourceManager
    let healthKitManager: HealthKitManager
    let onRefresh: () async -> Void

    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 40)

            Image(systemName: heroIconName)
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(heroIconColor)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: 10) {
                Text(titleText)
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)

                Text(messageText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let progress = healthKitManager.syncProgress {
                syncProgressView(progress)
                    .padding(.horizontal, 32)
                    .padding(.top, 4)
            }

            Button {
                AppAnalytics.shared.trackBlockTap(
                    title: "Refresh",
                    type: .emptyStateRefresh,
                    screen: .home,
                    metadata: ["source": "empty_state"]
                )
                Task { await onRefresh() }
            } label: {
                Label(Copy.Settings.refreshNow, systemImage: "arrow.clockwise")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 32)
            .padding(.top, 4)

            Spacer()
        }
    }

    // MARK: - Connection State

    private enum ConnectionState {
        case waiting
        case receiving(ConnectedDeviceInfo)
        case stale(ConnectedDeviceInfo)
    }

    private var connectionState: ConnectionState {
        if let active = deviceSourceManager.activeDevices.first {
            return .receiving(active)
        }
        if let inactive = deviceSourceManager.inactiveDevices.first {
            return .stale(inactive)
        }
        return .waiting
    }

    private var primaryDevice: SupportedDevice? {
        switch connectionState {
        case .waiting: return nil
        case .receiving(let info), .stale(let info): return info.device
        }
    }

    private var heroIconName: String {
        if healthKitManager.syncProgress != nil {
            return "arrow.triangle.2.circlepath"
        }
        return primaryDevice?.systemImageName ?? "heart.text.square.fill"
    }

    private var heroIconColor: Color {
        switch connectionState {
        case .waiting: return .orange
        case .receiving: return primaryDevice?.iconColor ?? .green
        case .stale: return .orange
        }
    }

    private var titleText: String {
        if healthKitManager.syncProgress != nil {
            return Copy.Settings.syncingData
        }
        switch connectionState {
        case .waiting:
            return Copy.Settings.waitingForData
        case .receiving(let info):
            return Copy.Home.ConnectionStatus.titleReceiving(info.presentationName)
        case .stale:
            return Copy.Home.ConnectionStatus.titleStale
        }
    }

    private var messageText: String {
        if healthKitManager.syncProgress != nil {
            return "This only takes a moment. Your dashboard will appear as soon as the first numbers arrive."
        }
        switch connectionState {
        case .waiting:
            return Copy.Settings.waitingForDataHint
        case .receiving(let info):
            return "Your \(info.presentationName) is syncing through \(info.sourceDisplayName). Your dashboard updates as new data arrives."
        case .stale(let info):
            return "Your \(info.presentationName) last synced \(info.lastSyncText.lowercased()). Open \(info.sourceDisplayName) so Laso can catch up."
        }
    }

    // MARK: - Sync Progress

    @ViewBuilder
    private func syncProgressView(_ progress: HealthKitManager.SyncProgress) -> some View {
        VStack(spacing: 8) {
            ProgressView(
                value: Double(progress.metricsCompleted),
                total: Double(max(progress.totalMetrics, 1))
            )
            .tint(.blue)

            Text("\(progress.metricsCompleted) of \(progress.totalMetrics) metrics")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
