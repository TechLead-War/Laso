import SwiftUI

/// Small badge showing trend direction with color coding.
/// Arrow follows numeric change direction when `numericChange` is supplied,
/// otherwise falls back to sentiment-based arrow from `TrendDirection`.
struct TrendBadge: View {
    let direction: TrendDirection
    let changeText: String?
    let numericChange: Double?

    init(direction: TrendDirection, changeText: String? = nil, numericChange: Double? = nil) {
        self.direction = direction
        self.changeText = changeText
        self.numericChange = numericChange
    }

    private var arrowImageName: String {
        if let numericChange {
            return TrendDirection.arrowImageName(forChange: numericChange)
        }
        return direction.systemImageName
    }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: arrowImageName)
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
        .background(AppColour.surfaceSubtle, in: Capsule())
    }
}

#Preview {
    VStack(spacing: 10) {
        TrendBadge(direction: .improving, changeText: "+5.2%", numericChange: 5.2)
        TrendBadge(direction: .improving, changeText: "-36.0%", numericChange: -36.0)
        TrendBadge(direction: .stable)
        TrendBadge(direction: .declining, changeText: "-8.1%", numericChange: -8.1)
        TrendBadge(direction: .declining, changeText: "+8.1%", numericChange: 8.1)
    }
}
