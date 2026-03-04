import SwiftUI

/// Small badge showing trend direction with color coding
struct TrendBadge: View {
    let direction: TrendDirection
    let changeText: String?

    init(direction: TrendDirection, changeText: String? = nil) {
        self.direction = direction
        self.changeText = changeText
    }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: direction.systemImageName)
                .font(.caption2.weight(.bold))

            if let changeText {
                Text(changeText)
                    .font(.caption2.weight(.medium))
            } else {
                Text(direction.displayName)
                    .font(.caption2.weight(.medium))
            }
        }
        .foregroundStyle(direction.color)
        .padding(.horizontal, DS.badgeH)
        .padding(.vertical, DS.badgeV)
        .background(direction.color.opacity(DS.badgeBg), in: Capsule())
    }
}

#Preview {
    VStack(spacing: 10) {
        TrendBadge(direction: .improving, changeText: "+5.2%")
        TrendBadge(direction: .stable)
        TrendBadge(direction: .declining, changeText: "-8.1%")
    }
}
