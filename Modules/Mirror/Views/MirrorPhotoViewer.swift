import SwiftUI

/// Full screen, uncropped view of one Daily Mirror photo. Every surface that
/// shows a cropped thumbnail (Explore day sheet, weekly strip) opens this on
/// tap; tapping anywhere or Close dismisses.
struct MirrorPhotoViewer: View {
    let photo: UIImage
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Image(uiImage: photo)
                .resizable()
                .scaledToFit()
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
}
