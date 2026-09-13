import SwiftUI

/// A value drawn against the person's own usual range: a quiet track, the
/// usual band as a lighter segment, and one dot for today. Shared by the
/// driver rows on Today, the Body rows and the driver detail "Your usual"
/// row, so a reading looks the same wherever it appears.
struct UsualBandBar: View {
    let band: UsualBand
    let tone: DailyBrief.Tone

    private static let trackHeight: CGFloat = 5
    private static let dotSize: CGFloat = 11

    /// The drawn scale runs one band-width past each edge of the usual range,
    /// so a value just outside the band still lands on the track instead of
    /// being clamped onto its edge and reading as "at usual".
    private var scale: ClosedRange<Double> {
        let width = max(band.high - band.low, 0.001)
        return (band.low - width)...(band.high + width)
    }

    private func fraction(_ value: Double) -> CGFloat {
        let clamped = min(max(value, scale.lowerBound), scale.upperBound)
        return CGFloat((clamped - scale.lowerBound) / (scale.upperBound - scale.lowerBound))
    }

    private var dotColor: Color {
        switch tone {
        case .good, .neutral: return AppColour.scoreGood
        case .fair: return AppColour.scoreFair
        case .poor: return AppColour.scorePoor
        }
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(AppColour.trackNeutral)
                    .frame(height: Self.trackHeight)

                Capsule()
                    .fill(AppColour.scoreGood.opacity(DS.badgeBg))
                    .frame(width: width * (fraction(band.high) - fraction(band.low)), height: Self.trackHeight)
                    .offset(x: width * fraction(band.low))

                Circle()
                    .fill(dotColor)
                    .overlay(Circle().strokeBorder(AppColour.surfaceRaised, lineWidth: 2))
                    .frame(width: Self.dotSize, height: Self.dotSize)
                    .offset(x: width * fraction(band.value) - Self.dotSize / 2)
            }
            .frame(height: Self.dotSize)
        }
        .frame(height: Self.dotSize)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(band.rangeText)
    }
}
