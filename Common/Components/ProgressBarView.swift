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
                    .frame(width: geo.size.width * min(max(fraction, 0), 1.0), height: height)
            }
        }
        .frame(height: height)
    }
}
