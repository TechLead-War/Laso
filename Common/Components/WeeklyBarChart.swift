import SwiftUI

struct WeeklyBarChart<Point: Identifiable>: View {
    let points: [Point]
    let value: (Point) -> Double
    let color: (Point) -> Color
    let label: (Point) -> String
    var maxBarHeight: CGFloat = 80
    var topLabel: ((Point) -> String)? = nil
    /// Optional tooltip lines shown above the selected bar on tap. Provide
    /// caller-formatted strings (e.g. ["Mon, Apr 26", "1.8 / 3", "Elevated"]).
    var tooltipLines: ((Point) -> [String])? = nil
    /// Tooltip accent color. Falls back to the bar color when nil.
    var tooltipColor: ((Point) -> Color)? = nil

    @State private var selectedID: Point.ID?

    private var selectedPoint: Point? {
        guard let selectedID else { return nil }
        return points.first { $0.id == selectedID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let selectedPoint, let tooltipLines {
                tooltipView(for: selectedPoint, lines: tooltipLines(selectedPoint))
            }

            HStack(alignment: .bottom, spacing: 6) {
                ForEach(points) { point in
                    barCell(for: point)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: maxBarHeight + (topLabel != nil ? 40 : 20))
        }
        .frame(maxWidth: .infinity)
        .sensoryFeedback(.selection, trigger: selectedID.map { String(describing: $0) })
    }

    private func barCell(for point: Point) -> some View {
        let isSelected = selectedID == point.id
        let barColor = color(point)

        return VStack(spacing: 4) {
            if let topLabel {
                Text(topLabel(point))
                    .font(.caption2.weight(.bold).monospacedDigit())
                    .foregroundStyle(barColor)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .postHogMask()
            }

            RoundedRectangle(cornerRadius: 4)
                .fill(barColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isSelected ? Color.primary.opacity(0.85) : .clear, lineWidth: 1.5)
                )
                .frame(height: max(CGFloat(min(max(value(point), 0), 1.0)) * maxBarHeight, 4))
                .scaleEffect(isSelected ? 1.05 : 1.0)
                .animation(.easeOut(duration: 0.15), value: isSelected)

            Text(label(point))
                .font(.caption2.weight(isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? Color.primary : .secondary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            guard tooltipLines != nil else { return }
            if selectedID == point.id {
                selectedID = nil
            } else {
                selectedID = point.id
            }
        }
    }

    private func tooltipView(for point: Point, lines: [String]) -> some View {
        let accent = tooltipColor?(point) ?? color(point)
        return VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                if index == 0 {
                    Text(line)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else if index == 1 {
                    Text(line)
                        .font(.callout.weight(.bold).monospacedDigit())
                        .foregroundStyle(accent)
                } else {
                    Text(line)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(accent)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
    }
}
