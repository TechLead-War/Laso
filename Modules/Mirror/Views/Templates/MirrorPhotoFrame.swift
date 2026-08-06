import SwiftUI
import UIKit

enum MirrorDesign {
    /// Every template is authored in this width, so a point in a template is
    /// the same point on a gallery tile, on a full screen viewer and in the
    /// exported JPEG. The frame below is the only thing that scales.
    static let width: CGFloat = 390
}

/// A Daily Mirror photo with its overlay drawn on top, at any size.
///
/// This is the single place a stored photo becomes a finished picture. Every
/// surface that shows the archive goes through it, so a template change or a
/// legibility fix lands everywhere at once instead of in one screen at a time.
struct MirrorPhotoFrame: View {
    let photo: UIImage
    let template: MirrorTemplate
    let payload: MirrorPayload
    var analysis: MirrorLegibility.Analysis = .unknown
    var archive: MirrorArchiveSlice = .empty
    var personMask: UIImage?
    /// False for photos captured before the overlay moved out of the pixels.
    /// Drawing over those would print a second stamp on top of the first.
    var drawsOverlay: Bool = true

    var body: some View {
        GeometryReader { proxy in
            let scale = max(proxy.size.width, 1) / MirrorDesign.width
            let designHeight = proxy.size.height / max(scale, 0.001)

            ZStack {
                // Three templates compose the photo into their own layout, so
                // drawing it full bleed underneath them would show through.
                if !drawsOverlay || !MirrorOverlay.drawsOwnPhoto(template) {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                }

                if drawsOverlay {
                    MirrorOverlay(
                        template: template,
                        payload: payload,
                        analysis: analysis,
                        archive: archive,
                        photo: photo,
                        personMask: personMask
                    )
                    .frame(width: MirrorDesign.width, height: designHeight)
                    .scaleEffect(scale)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
            .environment(\.colorScheme, .dark)
        }
    }
}

extension MirrorPhotoFrame {
    /// Builds the frame for a stored day, doing the archive reads the chosen
    /// template actually needs and skipping them for the fifteen that do not.
    @MainActor
    static func forStoredDay(
        _ date: Date,
        store: MirrorPhotoStore = .shared,
        thumbnail: Bool = false
    ) -> MirrorPhotoFrame? {
        guard let meta = store.meta(on: date) else { return nil }
        let image = thumbnail ? store.thumbnail(on: date) : store.image(on: date)
        guard let image else { return nil }

        guard let template = meta.resolvedTemplate, let payload = meta.payload else {
            // A photo from before templates were stored. It already carries its
            // overlay, so it is shown exactly as it was written.
            return MirrorPhotoFrame(
                photo: image, template: .clean, payload: .empty, drawsOverlay: false
            )
        }

        return MirrorPhotoFrame(
            photo: image,
            template: template,
            payload: payload,
            archive: MirrorArchiveSlice.build(for: template.archiveNeed, endingOn: date, store: store),
            personMask: template == .behindYou ? store.personMask(on: date) : nil
        )
    }
}

/// Flattens a photo and its overlay into one image, for the share sheet and for
/// the opt in copy into the system Photos app.
///
/// This is the only place an overlay is burned into pixels now, and it happens
/// on the way out of the app rather than on the way into the archive.
@MainActor
enum MirrorPhotoRenderer {
    static func render(
        photo: UIImage,
        template: MirrorTemplate,
        payload: MirrorPayload,
        analysis: MirrorLegibility.Analysis = .unknown,
        archive: MirrorArchiveSlice = .empty,
        personMask: UIImage? = nil
    ) -> UIImage {
        guard template != .clean, photo.size.width > 0 else { return photo }

        let designHeight = MirrorDesign.width * photo.size.height / photo.size.width
        let content = MirrorPhotoFrame(
            photo: photo,
            template: template,
            payload: payload,
            analysis: analysis,
            archive: archive,
            personMask: personMask
        )
        .frame(width: MirrorDesign.width, height: designHeight)

        let renderer = ImageRenderer(content: content)
        renderer.scale = photo.size.width * photo.scale / MirrorDesign.width
        return renderer.uiImage ?? photo
    }

    /// The finished picture for a stored day, or nil when there is no photo.
    static func renderStoredDay(_ date: Date, store: MirrorPhotoStore = .shared) -> UIImage? {
        guard let meta = store.meta(on: date), let image = store.image(on: date) else { return nil }
        guard let template = meta.resolvedTemplate, let payload = meta.payload else {
            return image  // already baked
        }
        return render(
            photo: image,
            template: template,
            payload: payload,
            archive: MirrorArchiveSlice.build(for: template.archiveNeed, endingOn: date, store: store),
            personMask: template == .behindYou ? store.personMask(on: date) : nil
        )
    }
}
