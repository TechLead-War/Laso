import SwiftUI

/// Signed wake-time drift around a fixed anchor: marks grow up for a late wake
/// and down for an early one, from a centre line that *is* the anchor.
///
/// Built rather than reusing `WeeklyBarChart` because that grows every bar one
/// direction from a baseline. Signed drift needs a centre line, and the whole
/// point of the visual is which side of the anchor a night landed on.
struct WakeDriftStrip: View {

    let points: [WakeDriftPoint]
    /// Half-width of the shaded band, in minutes.
    let bandMinutes: Int

    var height: CGFloat = 56
    /// Marks are spread across the full width rather than laid out at a fixed
    /// pitch, so a 14-night strip and a 28-night strip both fill the card
    /// instead of trailing off halfway.
    var maxMarkWidth: CGFloat = 4

    /// Drift beyond this is clipped to full height. Without a ceiling one bad
    /// night (a 4-hour lie-in) flattens every other mark to invisible.
    private var ceilingMinutes: Double { Double(max(bandMinutes, 1)) * 3 }

    var body: some View {
        Canvas { context, size in
            let centre = size.height / 2
            let halfHeight = size.height / 2
            let bandHalf = min(Double(bandMinutes) / ceilingMinutes, 1) * halfHeight

            context.fill(
                Path(CGRect(x: 0, y: centre - bandHalf, width: size.width, height: bandHalf * 2)),
                with: .color(AppColour.chartBandFill)
            )

            context.fill(
                Path(CGRect(x: 0, y: centre - 0.5, width: size.width, height: 1)),
                with: .color(AppColour.chartZeroLine)
            )

            let step = size.width / CGFloat(max(points.count, 1))
            let markWidth = max(1, min(maxMarkWidth, step * 0.55))

            for (index, point) in points.enumerated() {
                let x = CGFloat(index) * step + (step - markWidth) / 2

                let magnitude = min(Double(abs(point.driftMinutes)) / ceilingMinutes, 1)
                // A zero-drift night must still draw, so the mark never
                // disappears on the user's steadiest days.
                let markHeight = max(magnitude * halfHeight, markWidth)
                let isLate = point.driftMinutes >= 0
                let y = isLate ? centre - markHeight : centre

                let rect = CGRect(x: x, y: y, width: markWidth, height: markHeight)
                let inBand = abs(point.driftMinutes) <= bandMinutes
                context.fill(
                    Path(roundedRect: rect, cornerRadius: markWidth / 2),
                    with: .color(inBand ? AppColour.categorySleep : AppColour.warning)
                )
            }
        }
        .frame(height: height)
        .accessibilityElement()
        .accessibilityLabel(accessibilityLabel)
    }

    /// The strip is decorative on its own; the card's status line carries the
    /// same numbers, so VoiceOver gets the summary rather than 28 bars.
    private var accessibilityLabel: String {
        let inBand = points.filter { abs($0.driftMinutes) <= bandMinutes }.count
        return Copy.WakeAnchor.landedWithin(
            minutes: bandMinutes,
            hits: inBand,
            total: points.count
        )
    }
}
