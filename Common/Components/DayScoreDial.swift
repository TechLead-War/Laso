import SwiftUI

/// A ring of ticks, filled in proportion to the day's score and tinted by its
/// band. A day that was never scored draws a single dot instead, because that is
/// a different thing from a low score and has to look different.
///
/// Shared rather than owned by the month calendar: Home's week strip draws the
/// same day at the same size, and two copies of this arc would drift the moment
/// either band colour or tick count moved.
struct DayScoreDial: View {
    let score: Int?

    private static let tickStroke = StrokeStyle(lineWidth: 1.8, lineCap: .round)

    private var litTickCount: Int {
        guard let score else { return 0 }
        let fraction = Double(score) / 100
        let ticks = Int((Double(TickArc.tickCount) * fraction).rounded())
        // A score outside 0...100 would build a reversed Range and trap.
        return min(TickArc.tickCount, max(0, ticks))
    }

    var body: some View {
        let lit = litTickCount

        ZStack {
            if let score {
                // Disjoint ranges, so the two strokes never overlap and the
                // result is pixel-identical to colouring each tick individually.
                TickArc(range: lit..<TickArc.tickCount)
                    .stroke(AppColour.trackNeutral, style: Self.tickStroke)
                if lit > 0 {
                    TickArc(range: 0..<lit)
                        .stroke(DashboardViewModel.RecoveryState(score: score).color, style: Self.tickStroke)
                }
            } else {
                // No score is not a low score. A full grey ring drew an
                // unrecorded day exactly as heavily as a scored one, and in a
                // half-finished month that is most of the grid. A dot separates
                // "nothing recorded" from "scored low" by kind, not by weight.
                Circle()
                    .fill(AppColour.trackNeutral)
                    .frame(width: 4, height: 4)
            }
        }
        .accessibilityHidden(true)
    }
}

/// The tick ring itself. Lives beside its only consumer so the tick count and
/// the arc geometry stay in one place.
struct TickArc: Shape {
    static let tickCount = 20

    let range: Range<Int>

    func path(in rect: CGRect) -> Path {
        let centreX: Double = rect.width / 2
        let centreY: Double = rect.height / 2
        let inner: Double = rect.width * 0.30
        let outer: Double = rect.width * 0.48

        var path = Path()
        for index in range {
            let angle: Double = (Double(index) / Double(Self.tickCount)) * 2 * .pi - .pi / 2
            let cosine: Double = cos(angle)
            let sine: Double = sin(angle)
            path.move(to: CGPoint(x: centreX + inner * cosine, y: centreY + inner * sine))
            path.addLine(to: CGPoint(x: centreX + outer * cosine, y: centreY + outer * sine))
        }
        return path
    }
}
