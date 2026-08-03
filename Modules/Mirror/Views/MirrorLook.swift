import CoreImage
import UIKit

/// The colour treatment baked into a Daily Mirror photo, chosen at capture and
/// applied to the pixels before the data overlay is drawn on top.
///
/// All six are stock `CIPhotoEffect` presets: no tuning parameters, no custom
/// kernels, and consistent results across every device Core Image runs on.
enum MirrorLook: String, CaseIterable, Identifiable {
    case original, noir, chrome, fade, instant, warm

    var id: String { rawValue }

    var label: String {
        switch self {
        case .original: return Copy.Mirror.lookOriginal
        case .noir:     return Copy.Mirror.lookNoir
        case .chrome:   return Copy.Mirror.lookChrome
        case .fade:     return Copy.Mirror.lookFade
        case .instant:  return Copy.Mirror.lookInstant
        case .warm:     return Copy.Mirror.lookWarm
        }
    }

    fileprivate var ciFilterName: String? {
        switch self {
        case .original: return nil
        case .noir:     return "CIPhotoEffectNoir"
        case .chrome:   return "CIPhotoEffectChrome"
        case .fade:     return "CIPhotoEffectFade"
        case .instant:  return "CIPhotoEffectInstant"
        case .warm:     return "CIPhotoEffectProcess"
        }
    }
}

enum MirrorLookRenderer {

    /// One context for the whole app. Building a `CIContext` allocates the
    /// Metal pipeline behind it, so a per-call context turns the filter strip
    /// into a slideshow.
    private static let context = CIContext()

    /// Returns the photo unchanged for `.original` and for any filter that
    /// fails, so a colour look can never lose the user's capture.
    static func apply(_ look: MirrorLook, to image: UIImage) -> UIImage {
        guard let name = look.ciFilterName,
              let cgImage = image.cgImage,
              let filter = CIFilter(name: name)
        else { return image }

        filter.setValue(CIImage(cgImage: cgImage), forKey: kCIInputImageKey)
        guard let output = filter.outputImage,
              let filtered = context.createCGImage(output, from: output.extent)
        else { return image }

        // Orientation is carried on the UIImage, not the CGImage: front camera
        // captures arrive mirrored, and dropping it would flip the photo.
        return UIImage(cgImage: filtered, scale: image.scale, orientation: image.imageOrientation)
    }
}
