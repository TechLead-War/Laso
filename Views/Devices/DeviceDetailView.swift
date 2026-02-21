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
    }

    private var deviceHeader: some View {
        VStack(spacing: 12) {
            Image(systemName: device.systemImageName)
                .font(.system(size: 44))
                .foregroundStyle(device.iconColor)

            Text(device.displayName)
                .font(.title2.weight(.bold))

            statusBadge
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
                Text("Not Connected")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.secondary, in: Capsule())
            }
        }
    }

    private func connectedContent(_ info: ConnectedDeviceInfo) -> some View {
        VStack(spacing: 16) {
            // Summary
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

            // Metrics by category
            VStack(alignment: .leading, spacing: 12) {
                Text("Tracked Metrics")
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

            // Source info
            VStack(alignment: .leading, spacing: 6) {
                Text("Source")
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
            // Expected metrics
            VStack(alignment: .leading, spacing: 8) {
                Text("\(device.supportedMetrics.count) metrics available")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal)

                Text("Connect this device to start tracking these health metrics automatically.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background, in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal)

            // Setup guide
            DeviceSetupGuideView(device: device)
                .padding(.horizontal)
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
