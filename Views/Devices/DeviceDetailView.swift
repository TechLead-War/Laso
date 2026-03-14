import SwiftUI

/// Detail view for a single device — shows connected metrics or setup instructions
struct DeviceDetailView: View {
    let device: SupportedDevice
    let deviceInfo: ConnectedDeviceInfo?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Device Header
                deviceHeader

                if let info = deviceInfo {
                    // Connected device — show metrics
                    connectedContent(info)
                } else {
                    // Not connected — show setup guide
                    notConnectedContent
                }
            }
            .padding(.bottom)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(device.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            AppAnalytics.shared.trackFeatureOpen(.deviceDetail, metadata: [
                "device": device.displayName,
                "is_connected": deviceInfo != nil ? "true" : "false"
            ])
        }
        .onDisappear {
            AppAnalytics.shared.trackFeatureClose(.deviceDetail, metadata: [
                "device": device.displayName
            ])
        }
    }

    private var deviceHeader: some View {
        VStack(spacing: 12) {
            Image(systemName: device.systemImageName)
                .font(.system(size: 44))
                .foregroundStyle(device.iconColor)

            Text(device.displayName)
                .font(.title2.weight(.bold))

            statusBadge

            Text(sourceSubtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top)
    }

    private var statusBadge: some View {
        Group {
            if let info = deviceInfo {
                Text(info.isActive ? "Active" : "Inactive")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(info.isActive ? .green : .orange, in: Capsule())
            } else {
                Text("Available Source")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.blue, in: Capsule())
            }
        }
    }

    private func connectedContent(_ info: ConnectedDeviceInfo) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 0) {
                VStack(spacing: 4) {
                    Text("\(info.metricCount)")
                        .font(.title2.weight(.bold).monospacedDigit())
                    Text("Metrics")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                Divider().frame(height: 40)

                VStack(spacing: 4) {
                    Text(info.sourceName)
                        .font(.title3.weight(.semibold))
                    Text("Source App")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                Divider().frame(height: 40)

                VStack(spacing: 4) {
                    Text(info.lastSyncText)
                        .font(.title3.weight(.semibold))
                    Text("Last Sync")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 12)
            .background(.background, in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal)

            VStack(alignment: .leading, spacing: 10) {
                Text("Sync Path")
                    .font(.subheadline.weight(.semibold))
                Text(syncPathDescription(for: info))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding()
            .background(.background, in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal)

            VStack(alignment: .leading, spacing: 12) {
                Text("Imported Metrics")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal)

                ForEach(HealthCategory.allCases) { category in
                    let metricsInCategory = info.metricsProvided.filter { $0.category == category }.sorted { $0.displayName < $1.displayName }
                    if !metricsInCategory.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Image(systemName: category.systemImageName)
                                    .font(.caption)
                                    .foregroundStyle(category.color)
                                Text(category.displayName)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal)

                            FlowLayout(spacing: 6) {
                                ForEach(metricsInCategory, id: \.self) { metric in
                                    Text(metric.displayName)
                                        .font(.caption2)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(category.color.opacity(0.1), in: Capsule())
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.vertical, 12)
            .background(.background, in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal)

            VStack(alignment: .leading, spacing: 6) {
                Text("Data Source")
                    .font(.subheadline.weight(.semibold))
                HStack {
                    Text("App: \(info.sourceName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                HStack {
                    Text("Bundle: \(info.sourceBundleId)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
            }
            .padding()
            .background(.background, in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal)
        }
    }

    private var notConnectedContent: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("\(device.supportedMetrics.count) metrics available")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal)

                Text(notConnectedDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background, in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal)

            VStack(alignment: .leading, spacing: 8) {
                Text("How It Fits Your Setup")
                    .font(.subheadline.weight(.semibold))
                Text(setupFitDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding()
            .background(.background, in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal)

            DeviceSetupGuideView(device: device)
                .padding(.horizontal)
        }
    }

    private var sourceSubtitle: String {
        if let sourceName = deviceInfo?.sourceName {
            return sourceName
        }
        switch device {
        case .appleWatch:
            return "Watch app + Apple Health"
        case .iPhone:
            return "iPhone sensors + Apple Health"
        default:
            return "\(device.companionAppName) + Apple Health"
        }
    }

    private func syncPathDescription(for info: ConnectedDeviceInfo) -> String {
        switch device {
        case .appleWatch:
            return "Apple Watch records samples, Apple Health keeps them synced to iPhone, and Laso imports them automatically on refresh."
        case .iPhone:
            return "iPhone sensors write to Apple Health directly, and Laso imports those samples automatically on refresh."
        default:
            return "\(device.displayName) writes to \(info.sourceName), Apple Health receives the samples, and Laso imports them automatically on refresh."
        }
    }

    private var notConnectedDescription: String {
        switch device {
        case .appleWatch:
            return "Apple Watch starts appearing here after it records health samples and syncs them into Apple Health."
        case .iPhone:
            return "iPhone motion and activity metrics appear here after Apple Health records the first samples."
        default:
            return "\(device.displayName) can feed data into Laso once \(device.companionAppName) is allowed to write to Apple Health."
        }
    }

    private var setupFitDescription: String {
        switch device {
        case .appleWatch:
            return "Apple Watch is the best source for live heart rate, oxygen, and readiness signals. Keep it connected if you want real-time vitals."
        case .iPhone:
            return "iPhone-only tracking still gives Laso steps, distance, workouts, and other Health data even without a wearable."
        default:
            return "Your main device can stay connected. Add \(device.displayName) only if you want broader metric coverage or a different source app."
        }
    }
}

/// Simple flow layout for metric tags
struct FlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (CGSize(width: maxX, height: y + rowHeight), positions)
    }
}

#Preview {
    NavigationStack {
        DeviceDetailView(device: .garmin, deviceInfo: nil)
    }
}
