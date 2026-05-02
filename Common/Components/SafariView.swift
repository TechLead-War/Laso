import SwiftUI
import SafariServices

/// In-app Safari sheet. Used for Terms / Privacy from inside a fullScreenCover
/// (paywall) where SwiftUI `Link` is unreliable on iPad and a tap appears to
/// do nothing — App Review flagged this as a bug on iPadOS 26.
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}

/// Wraps a URL so it can drive `.sheet(item:)`.
struct IdentifiedURL: Identifiable {
    let id = UUID()
    let url: URL
}
