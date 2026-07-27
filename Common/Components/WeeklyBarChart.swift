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
    /// Where the person's own average sits, in the same 0 to 1 space as `value`.
    /// Without it the bars float against nothing and a reader cannot tell a good
    /// day from a bad one. Nil when the caller has no real average to show; the
    /// line is never drawn from an assumed number.
    var referenceFraction: Double? = nil
    /// Short caption for that line, e.g. "Your average".
    var referenceLabel: String? = nil

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

            // The bars sit in their own fixed-height plot area so the average
            // line can be positioned against the same baseline the bars grow
            // from. Day labels live below it, outside the plot.
            ZStack(alignment: .bottom) {
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(points) { point in
                        barCell(for: point)
                    }
                }
                referenceLine
            }
            .frame(maxWidth: .infinity)
            .frame(height: maxBarHeight + (topLabel != nil ? 40 : 20))
        }
        .frame(maxWidth: .infinity)
        .sensoryFeedback(.selection, trigger: selectedID.map { String(describing: $0) })
    }

    /// Dashed line across the plot at the person's own average, with its caption
    /// tucked above the line so it never covers a bar.
    @ViewBuilder
    private var referenceLine: some View {
        if let referenceFraction {
            let clamped = min(max(referenceFraction, 0), 1)
            HStack(spacing: 6) {
                Rectangle()
                    .fill(Color.primary.opacity(0.30))
                    .frame(height: 1)
                if let referenceLabel {
                    // Caption rides at the end of the line rather than above it,
                    // so a low average cannot drop its text onto the bars.
                    Text(referenceLabel)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .fixedSize()
                }
            }
            // Offset from the same baseline the bars grow from, clearing the
            // day-label row underneath.
            .padding(.bottom, (maxBarHeight * clamped) + 20)
            .allowsHitTesting(false)
        }
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
