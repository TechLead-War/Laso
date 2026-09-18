import SwiftUI

struct LiveStatusFooter: View {
    let lastUpdate: Date?

    var body: some View {
        Group {
            if let lastUpdate {
                HStack(spacing: 6) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(DS.Typography.caption2)
                    Copy.Live.lastSignalAgoStyledText(lastUpdate)
                        .font(DS.Typography.caption2)
                }
                .foregroundStyle(AppColour.textTertiary)
                .padding(.bottom, DS.space2)
            }
        }
    }
}
