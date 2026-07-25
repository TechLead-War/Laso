import SwiftUI

struct ProgressBarView: View {
    let fraction: Double
    let color: Color
    var height: CGFloat = 6
    var trackColor: Color? = nil

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(trackColor ?? Color(.systemGray5))
                    .frame(height: height)

                RoundedRectangle(cornerRadius: height / 2)
                    .fill(color)
                    .frame(width: fillWidth(in: geo.size.width), height: height)
            }
        }
        .frame(height: height)
    }

    /// A small but real value is never thinner than the bar is tall, otherwise a
    /// 1% or 2% driver draws as a dot and reads as no data. Zero still draws nothing.
    private func fillWidth(in totalWidth: CGFloat) -> CGFloat {
        let clamped = min(max(fraction, 0), 1.0)
        guard clamped > 0 else { return 0 }
        return max(totalWidth * clamped, height)
    }
}
