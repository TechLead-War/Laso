import SwiftUI

struct LiveStatusFooter: View {
    let lastUpdate: Date?

    var body: some View {
        Group {
            if let lastUpdate {
                HStack(spacing: 6) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.caption2)
                    Text("Last signal \(lastUpdate, style: .relative) ago")
                        .font(.caption2)
                }
                .foregroundStyle(.tertiary)
                .padding(.bottom, DS.space2)
            }
        }
    }
}
