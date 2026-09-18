import SwiftUI

/// Full screen, uncropped view of one Daily Mirror day. Every surface that
/// shows a cropped thumbnail (Explore day sheet, weekly strip) opens this on
/// tap; tapping anywhere or Close dismisses.
///
/// Takes a day rather than an image: the overlay is drawn from the day's stored
/// template now, so the caller has nothing to composite and cannot get it wrong.
struct MirrorPhotoViewer: View {
    let date: Date
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let frame = MirrorPhotoFrame.forStoredDay(date) {
                // Fitted, not filled: the whole photo stays visible, which is
                // the only reason this screen exists.
                Color.clear
                    .aspectRatio(aspect, contentMode: .fit)
                    .overlay { frame }
                    .clipped()
            }
        }
        .overlay(alignment: .topTrailing) {
            Button(Copy.Explore.dayClose) { onClose() }
                .font(DS.Typography.subheadlineSemibold)
                .foregroundStyle(.white)
                .padding(.horizontal, DS.space4)
                .padding(.vertical, DS.space2)
                .background(.white.opacity(0.15), in: Capsule())
                .padding(DS.space4)
        }
        .onTapGesture { onClose() }
    }

    /// Read from the thumbnail so the full size JPEG is not decoded twice just
    /// to learn its shape.
    private var aspect: CGFloat {
        guard let thumb = MirrorPhotoStore.shared.thumbnail(on: date), thumb.size.height > 0 else {
            return 3.0 / 4.0
        }
        return thumb.size.width / thumb.size.height
    }
}
