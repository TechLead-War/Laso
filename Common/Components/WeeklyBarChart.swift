import SwiftUI

struct WeeklyBarChart<Point: Identifiable>: View {
    let points: [Point]
    let value: (Point) -> Double
    let color: (Point) -> Color
    let label: (Point) -> String
    var maxBarHeight: CGFloat = 80
    var topLabel: ((Point) -> String)? = nil

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(points) { point in
                VStack(spacing: 4) {
                    if let topLabel {
                        Text(topLabel(point))
                            .font(.caption2.weight(.bold).monospacedDigit())
                            .foregroundStyle(color(point))
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                            .postHogMask()
                    }

                    RoundedRectangle(cornerRadius: 4)
                        .fill(color(point))
                        .frame(height: max(CGFloat(min(max(value(point), 0), 1.0)) * maxBarHeight, 4))

                    Text(label(point))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: maxBarHeight + (topLabel != nil ? 40 : 20))
    }
}
