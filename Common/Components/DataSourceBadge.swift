import SwiftUI

/// Small capsule badge showing which device provides a metric's data
struct DataSourceBadge: View {
    let device: SupportedDevice
    let sourceName: String?

    init(device: SupportedDevice, sourceName: String? = nil) {
        self.device = device
        self.sourceName = sourceName
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: device.systemImageName)
                .font(.caption2)
                .foregroundStyle(device.iconColor)

            Text(Copy.Common.viaText(sourceName ?? device.displayName))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, DS.badgeH)
        .padding(.vertical, DS.badgeV)
        .background(device.iconColor.opacity(DS.badgeBg), in: Capsule())
    }
}

#Preview {
    VStack(spacing: 8) {
        DataSourceBadge(device: .appleWatch)
        DataSourceBadge(device: .garmin, sourceName: "Garmin Connect")
        DataSourceBadge(device: .ouraRing)
    }
}
