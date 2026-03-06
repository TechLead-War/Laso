import SwiftUI

/// A reusable share button that renders a ShareableCard to an image and presents
/// the system share sheet via UIActivityViewController.
struct ShareButton: View {
    let cardType: ShareCardType
    let screen: AppFeature

    @State private var isRendering = false

    var body: some View {
        Button {
            shareCard()
        } label: {
            Image(systemName: "square.and.arrow.up")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .disabled(isRendering)
        .accessibilityLabel("Share health card")
        .accessibilityIdentifier("share.button")
    }

    private func shareCard() {
        guard !isRendering else { return }
        isRendering = true

        let cardView: AnyView
        let cardTypeLabel: String

        switch cardType {
        case .score(let score, let scoreChange, let streakDays):
            cardView = AnyView(ShareableScoreCard(
                score: score,
                scoreChange: scoreChange,
                streakDays: streakDays
            ))
            cardTypeLabel = "score"
        case .insight(let text, let metric, let category):
            cardView = AnyView(ShareableInsightCard(
                insightText: text,
                metricName: metric,
                category: category
            ))
            cardTypeLabel = "insight"
        }

        AppAnalytics.shared.trackBlockTap(
            title: "Share",
            type: .shareCard,
            screen: screen,
            metadata: ["card_type": cardTypeLabel]
        )

        let renderer = ImageRenderer(content: cardView)
        renderer.scale = UIScreen.main.scale

        guard let image = renderer.uiImage else {
            isRendering = false
            return
        }

        presentShareSheet(with: image)
        isRendering = false
    }

    private func presentShareSheet(with image: UIImage) {
        let activityItems: [Any] = [image]
        let activityVC = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            return
        }

        // Walk to the topmost presented controller
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }

        // iPad popover anchor
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = topVC.view
            popover.sourceRect = CGRect(
                x: topVC.view.bounds.midX,
                y: topVC.view.bounds.midY,
                width: 0,
                height: 0
            )
            popover.permittedArrowDirections = []
        }

        topVC.present(activityVC, animated: true)
    }
}

#Preview {
    HStack(spacing: 20) {
        ShareButton(
            cardType: .score(score: 78, scoreChange: 3, streakDays: 7),
            screen: .home
        )

        ShareButton(
            cardType: .insight(
                text: "Your sleep quality improved by 15% this week",
                metric: "Sleep Quality",
                category: "Sleep"
            ),
            screen: .explore
        )
    }
    .padding()
}
