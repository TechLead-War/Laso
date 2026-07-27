import SwiftUI

/// A reusable share button that renders a ShareableCard to an image and presents
/// the system share sheet via UIActivityViewController.
struct ShareButton: View {
    let cardType: ShareCardType
    let screen: AppFeature
    /// When set, renders as a full-width primary CTA instead of the bare icon.
    var title: String? = nil
    /// Optional text shared alongside the image (e.g. the referral invite
    /// line). Message apps attach it under the photo; Instagram ignores it,
    /// keeping the card itself clean.
    var captionText: String? = nil

    @State private var isRendering = false

    var body: some View {
        Button {
            shareCard()
        } label: {
            if let title {
                Label(title, systemImage: "square.and.arrow.up")
                    .font(DS.Typography.bodySemibold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppColour.info, in: RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, DS.screenPadding)
            } else {
                Image(systemName: "square.and.arrow.up")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
        .disabled(isRendering)
        .accessibilityLabel(Copy.Common.shareHealthCard)
        .accessibilityHint(Copy.Common.rendersThisCardAndOpensTheHint)
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
        case .template(let template, let photo):
            cardView = AnyView(ShareableTemplateCard(template: template, photo: photo))
            // Per-template label so Amplitude separates which win actually gets
            // posted, not just that a photo card was shared.
            cardTypeLabel = "template_\(template.kind.rawValue)"
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

        var activityItems: [Any] = [image]
        if let captionText, !captionText.isEmpty {
            activityItems.append(captionText)
        }
        Self.presentShareSheet(
            items: activityItems,
            // "_with_invite" marks shares that carried the referral caption so
            // referral-bearing completions are separable in Amplitude.
            contentType: activityItems.count > 1 ? "\(cardTypeLabel)_with_invite" : cardTypeLabel
        )
        isRendering = false
    }

    /// Presents the system share sheet from the topmost controller and reports
    /// share_completed with the given content_type. The single presenter for
    /// every share surface (cards here, the text invite in InviteFriendsView).
    static func presentShareSheet(items: [Any], contentType: String) {
        let activityVC = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        activityVC.excludedActivityTypes = [
            .print,
            .copyToPasteboard,
            .saveToCameraRoll,
            .assignToContact
        ]

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

        activityVC.completionWithItemsHandler = { activityType, completed, _, _ in
            AppAnalytics.shared.trackShareCompleted(
                contentType: contentType,
                activityType: activityType?.rawValue,
                completed: completed
            )
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
