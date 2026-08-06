import SwiftUI
import MessageUI

/// A reusable share button that renders a ShareableCard to an image and presents
/// the system share sheet via UIActivityViewController.
struct ShareButton: View {
    let cardType: ShareCardType
    let screen: AppFeature
    /// When set, renders as a full-width button instead of the bare icon.
    var title: String? = nil
    /// Whether the titled form carries the filled primary treatment. False when
    /// the direct-send button is present and owns that role: two identical
    /// filled buttons stacked give the user no hierarchy to read.
    var isPrimary: Bool = true
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
                    // White on the dark-mode info blue is only 2.63:1. textOnAccent
                    // flips with the fill and clears 5.7:1 light / 6.9:1 dark.
                    .foregroundStyle(isPrimary ? AppColour.textOnAccent : AppColour.info)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background {
                        if isPrimary {
                            RoundedRectangle(cornerRadius: 14).fill(AppColour.info)
                        }
                    }
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

    /// Renders a card to an image and returns it with its analytics label.
    ///
    /// The single renderer for every share path. The direct send and the
    /// activity sheet call the same function so the two can never put different
    /// artwork in front of the same user.
    static func render(_ cardType: ShareCardType) -> (image: UIImage, label: String)? {
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
        case .template(let template, let photo):
            cardView = AnyView(ShareableTemplateCard(template: template, photo: photo))
            // Per-template label so Amplitude separates which win actually gets
            // posted, not just that a photo card was shared.
            cardTypeLabel = "template_\(template.kind.rawValue)"
        }

        // The share cards are always-dark artwork, so the render is pinned to the
        // dark scheme. Without this a light-mode user gets light-variant tokens
        // drawn on a dark card.
        let renderer = ImageRenderer(content: cardView.environment(\.colorScheme, .dark))
        renderer.scale = UIScreen.main.scale

        guard let image = renderer.uiImage else { return nil }
        return (image, cardTypeLabel)
    }

    private func shareCard() {
        guard !isRendering else { return }
        isRendering = true

        guard let (image, cardTypeLabel) = Self.render(cardType) else {
            isRendering = false
            return
        }

        AppAnalytics.shared.trackBlockTap(
            title: "Share",
            type: .shareCard,
            screen: screen,
            metadata: ["card_type": cardTypeLabel]
        )

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

// MARK: - Direct send

/// Sends the card to one person through the Messages composer, with the card
/// already attached and the invite line already in the draft.
///
/// This sits above the activity sheet in the tray on purpose. Published
/// benchmarks put the large majority of real sharing traffic in private
/// messaging rather than public feeds, and health data is the category where
/// public posting collapses hardest: most people will send a number to family
/// or a friend and never post it. A private thread is also the only context
/// where a mediocre number is socially safe to send at all.
///
/// Hidden where the device cannot send messages, which includes the simulator.
struct SendToPersonButton: View {
    let cardType: ShareCardType
    let screen: AppFeature
    /// Referral invite line. Becomes the message body so the recipient gets a
    /// way in, rather than an image with no context.
    var captionText: String?

    @State private var composing = false
    /// Rendered once on tap and held for the composer. Re-rendering inside the
    /// completion handler just to recover the label would redraw the whole card
    /// for a string.
    @State private var rendered: (image: UIImage, label: String)?

    /// `canSendAttachments` and `canSendText` are both required: a device can be
    /// able to send texts while attachments are unavailable, and a card with no
    /// image is not worth sending.
    static var isAvailable: Bool {
        MFMessageComposeViewController.canSendText()
            && MFMessageComposeViewController.canSendAttachments()
    }

    var body: some View {
        Button {
            guard let card = ShareButton.render(cardType) else { return }
            rendered = card
            AppAnalytics.shared.trackBlockTap(
                title: "Share",
                type: .shareCard,
                screen: screen,
                metadata: ["card_type": card.label, "channel": "dm"]
            )
            composing = true
        } label: {
            Label(Copy.Common.shareSendToPerson, systemImage: "paperplane.fill")
                .font(DS.Typography.bodySemibold)
                .foregroundStyle(AppColour.textOnAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppColour.info, in: RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, DS.screenPadding)
        }
        .accessibilityIdentifier("share.send")
        .sheet(isPresented: $composing) {
            if let rendered {
                MessageComposeView(image: rendered.image, body: captionText) { result in
                    composing = false
                    // Reported through the same event as the activity sheet so
                    // the dm and social channels sit in one funnel and can be
                    // compared without joining two tables.
                    AppAnalytics.shared.trackShareCompleted(
                        contentType: rendered.label,
                        activityType: UIActivity.ActivityType.message.rawValue,
                        completed: result == .sent
                    )
                }
                .ignoresSafeArea()
            }
        }
    }
}

/// Messages composer wrapper.
///
/// `MFMessageComposeViewController` has no SwiftUI equivalent and is the only
/// way to open a recipient picker with the attachment already in the draft.
struct MessageComposeView: UIViewControllerRepresentable {
    let image: UIImage
    let body: String?
    let onFinish: (MessageComposeResult) -> Void

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let composer = MFMessageComposeViewController()
        composer.messageComposeDelegate = context.coordinator
        if let body, !body.isEmpty { composer.body = body }
        // PNG, not JPEG: the cards are flat colour fields and heavy type, and
        // JPEG rings visibly around the numerals at this size.
        if let data = image.pngData() {
            composer.addAttachmentData(data, typeIdentifier: "public.png", filename: "laso.png")
        }
        return composer
    }

    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    final class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        private let onFinish: (MessageComposeResult) -> Void
        init(onFinish: @escaping (MessageComposeResult) -> Void) { self.onFinish = onFinish }

        func messageComposeViewController(_ controller: MFMessageComposeViewController,
                                          didFinishWith result: MessageComposeResult) {
            onFinish(result)
        }
    }
}

#Preview {
    HStack(spacing: 20) {
        ShareButton(
            cardType: .score(score: 78, scoreChange: 3, streakDays: 7),
            screen: .home
        )

        ShareButton(
            cardType: .score(score: 78, scoreChange: 3, streakDays: 7),
            screen: .home,
            title: Copy.Common.shareCTA
        )
    }
    .padding()
}
