import SwiftUI

struct HomeErrorView: View {
    let message: String
    let onRetry: () async -> Void

    var body: some View {
        VStack(spacing: DS.space4) {
            Image(systemName: "exclamationmark.triangle")
                .font(DS.Typography.largeIcon)
                .foregroundStyle(AppColour.warning)
                .accessibilityHidden(true)

            Text(Copy.Home.unableToLoadData)
                .font(DS.Typography.title3)

            Text(message)
                .font(DS.Typography.body)
                .foregroundStyle(AppColour.textSecondary)
                .multilineTextAlignment(.center)

            Button(Copy.Home.tryAgain) {
                AppAnalytics.shared.trackBlockTap(
                    title: "Try Again",
                    type: .errorRetry,
                    screen: .home,
                    metadata: [
                        "source": "home_error_view"
                    ]
                )
                Task { await onRetry() }
            }
            .buttonStyle(.borderedProminent)
            .accessibilityHint("Retry loading health data")
        }
        .padding()
        .accessibilityElement(children: .combine)
        .onAppear {
            AppAnalytics.shared.trackError(type: "data_load_failed", screen: .home, message: message)
        }
    }
}
