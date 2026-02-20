import SwiftUI

/// Full-screen loading state with pulsing animation
struct LoadingView: View {
    @State private var isAnimating = false
    let message: String

    init(_ message: String = "Loading health data...") {
        self.message = message
    }

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart.text.clipboard")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
                .scaleEffect(isAnimating ? 1.1 : 0.9)
                .animation(.easeInOut(duration: 0.8).repeatForever(), value: isAnimating)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ProgressView()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { isAnimating = true }
    }
}

#Preview {
    LoadingView()
}
