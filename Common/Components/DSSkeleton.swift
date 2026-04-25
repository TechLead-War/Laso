import SwiftUI

/// Shimmer placeholder for loading states. Preserves layout during fetch so the
/// page doesn't jump when data arrives (Doherty threshold, <400ms perceived).
struct DSSkeleton: View {
    @State private var phase: CGFloat = 0
    var cornerRadius: CGFloat = DS.Radius.sm

    var body: some View {
        GeometryReader { geo in
            ZStack {
                AppColour.surfaceElevated

                LinearGradient(
                    colors: [
                        AppColour.surfaceElevated,
                        AppColour.surfaceOverlay,
                        AppColour.surfaceElevated
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: geo.size.width * 2)
                .offset(x: -geo.size.width + (phase * geo.size.width * 2))
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .onAppear {
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
        }
    }
}

/// Full-width skeleton card matching `cardStyle()` rhythm.
struct DSSkeletonCard: View {
    var height: CGFloat = 120
    var body: some View {
        DSSkeleton(cornerRadius: DS.cardRadius)
            .frame(height: height)
            .padding(.horizontal, DS.screenPadding)
    }
}
