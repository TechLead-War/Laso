import SwiftUI
import UIKit
import CoreImage
import CoreVideo
import Vision

/// Decides how much protection a block of type needs before it is drawn over a
/// photo, and where on the frame it is safe to put it.
///
/// There are only five ways to make type survive on an image: wash the whole
/// frame, scrim behind the block, a solid strip, space the photo already left
/// empty, or blur. Every template declares which one it uses. This type covers
/// the three that depend on what the camera actually saw, and it decides by
/// measuring rather than by hoping: a fixed 55% black bar is right for one
/// photo and wrong for the next.
enum MirrorLegibility {

    // MARK: - What we learned about the frame

    struct Analysis: Codable, Equatable {
        /// Face box in unit coordinates with y running down, matching SwiftUI.
        /// Nil when Vision found nobody, which is a normal outcome worth
        /// handling rather than an error.
        var face: CGRect?
        /// Mean luminance, 0 to 1, of each cell of a `gridSize` square grid,
        /// row major from the top left.
        var cells: [Double]

        static let gridSize = 6
        static let unknown = Analysis(face: nil, cells: [])

        /// Mean and spread of the cells a rect covers. Spread matters as much
        /// as brightness: an evenly dark background takes light type fine, a
        /// half bright half dark one fails somewhere in the middle whatever
        /// colour the type is.
        func luminance(in rect: CGRect) -> (mean: Double, spread: Double)? {
            guard cells.count == Self.gridSize * Self.gridSize else { return nil }
            let n = Double(Self.gridSize)
            var hits: [Double] = []
            for row in 0..<Self.gridSize {
                for column in 0..<Self.gridSize {
                    let cell = CGRect(x: Double(column) / n, y: Double(row) / n,
                                      width: 1 / n, height: 1 / n)
                    if cell.intersects(rect) { hits.append(cells[row * Self.gridSize + column]) }
                }
            }
            guard !hits.isEmpty else { return nil }
            let mean = hits.reduce(0, +) / Double(hits.count)
            return (mean, (hits.max() ?? 0) - (hits.min() ?? 0))
        }
    }

    /// How hard this photo is to write on at all. Drives the suggested
    /// template, not just the scrim.
    enum Difficulty: String, Codable {
        case easy, normal, hostile
    }

    // MARK: - The ladder

    /// Steps in order of how much of the photo they cost. The renderer walks up
    /// only as far as the measurement demands, so most photos keep their
    /// bottom third almost untouched.
    enum Protection: Int, Codable, Comparable {
        case none = 0
        case scrim
        case deepScrim
        case strip

        static func < (a: Protection, b: Protection) -> Bool { a.rawValue < b.rawValue }
    }

    /// Luminance above which white type stops clearing its contrast target.
    /// Large type carries a lower bar than body copy, the same split WCAG makes
    /// between 3:1 and 4.5:1.
    private static let brightCeilingLarge = 0.52
    private static let brightCeilingBody = 0.40
    /// A frame this uneven under the block cannot be fixed by a gradient,
    /// because whatever opacity suits one end blows out the other.
    private static let unevenSpread = 0.34

    /// The step needed for a block of type occupying `rect` in unit coordinates.
    static func protection(for rect: CGRect, analysis: Analysis, largeType: Bool) -> Protection {
        // No measurement means no confidence, so take the step that always
        // works rather than the one that usually does.
        guard let reading = analysis.luminance(in: rect) else { return .scrim }
        if reading.spread >= unevenSpread { return .strip }
        let ceiling = largeType ? brightCeilingLarge : brightCeilingBody
        if reading.mean >= ceiling + 0.18 { return .strip }
        if reading.mean >= ceiling { return .deepScrim }
        if reading.mean >= ceiling - 0.14 { return .scrim }
        return .none
    }

    static func difficulty(_ analysis: Analysis) -> Difficulty {
        // The bottom third is where nearly every template puts its type.
        let block = CGRect(x: 0, y: 0.66, width: 1, height: 0.34)
        guard let reading = analysis.luminance(in: block) else { return .normal }
        if reading.spread >= unevenSpread || reading.mean >= brightCeilingLarge + 0.18 { return .hostile }
        if reading.mean >= brightCeilingLarge { return .normal }
        return .easy
    }

    // MARK: - Measuring

    /// Face box and a luminance grid for a captured frame. Runs off the main
    /// actor: the Vision request is the slow part and the caller is holding a
    /// photo on screen while it waits.
    static func analyse(_ photo: UIImage) async -> Analysis {
        guard let cgImage = photo.cgImage else { return .unknown }
        return await Task.detached(priority: .userInitiated) {
            Analysis(face: faceBox(in: cgImage, orientation: photo.imageOrientation),
                     cells: luminanceGrid(cgImage))
        }.value
    }

    /// The subject cut out of the frame, as a white on black mask.
    ///
    /// Only Behind You needs it, and it is allowed to fail: an empty result is
    /// a normal outcome in a dark room, and the template has a path that never
    /// covers the face when there is no mask.
    static func personMask(_ photo: UIImage) async -> UIImage? {
        guard let cgImage = photo.cgImage else { return nil }
        return await Task.detached(priority: .userInitiated) { () -> UIImage? in
            let request = VNGeneratePersonSegmentationRequest()
            request.qualityLevel = .balanced
            request.outputPixelFormat = kCVPixelFormatType_OneComponent8
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
            guard let buffer = request.results?.first?.pixelBuffer else { return nil }
            let ciImage = CIImage(cvPixelBuffer: buffer)
            let context = CIContext(options: nil)
            guard let rendered = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
            return UIImage(cgImage: rendered)
        }.value
    }

    private static func faceBox(in image: CGImage, orientation: UIImage.Orientation) -> CGRect? {
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: image,
                                            orientation: cgOrientation(orientation),
                                            options: [:])
        try? handler.perform([request])
        guard let faces = request.results, !faces.isEmpty else { return nil }
        // The largest face is the subject. A reflection or a person behind
        // should not be what the layout dodges.
        let biggest = faces.max { $0.boundingBox.height < $1.boundingBox.height }
        guard let box = biggest?.boundingBox else { return nil }
        // Vision measures from the bottom left, SwiftUI from the top left.
        // Padded a little, because a template must clear hair and chin too.
        let flipped = CGRect(x: box.minX, y: 1 - box.maxY, width: box.width, height: box.height)
        return flipped.insetBy(dx: -flipped.width * 0.12, dy: -flipped.height * 0.16)
    }

    /// Mean luminance per cell, read from one small grayscale draw. Drawing the
    /// image straight into a gridSize square bitmap makes the hardware do the
    /// averaging, so this stays well under a millisecond.
    private static func luminanceGrid(_ image: CGImage) -> [Double] {
        let side = Analysis.gridSize
        var pixels = [UInt8](repeating: 0, count: side * side)
        guard let context = CGContext(
            data: &pixels, width: side, height: side, bitsPerComponent: 8,
            bytesPerRow: side, space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return [] }
        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
        // CGContext origin is bottom left, so rows come back upside down
        // relative to the unit rects callers hand in.
        return (0..<side).reversed().flatMap { row in
            (0..<side).map { Double(pixels[row * side + $0]) / 255.0 }
        }
    }

    private static func cgOrientation(_ orientation: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch orientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}

// MARK: - Drawing the protection

/// The gradient or bar a template puts behind its own type. Templates ask for
/// a step by name so the ladder stays in one place and every template escalates
/// the same way.
struct MirrorScrim: View {
    var protection: MirrorLegibility.Protection
    /// How tall the gradient is, in the 390 point design space.
    var height: CGFloat = 200
    var edge: Edge = .bottom

    var body: some View {
        switch protection {
        case .none:
            Color.clear.frame(height: 0)
        case .scrim:
            gradient(strong: 0.72, mid: 0.34)
        case .deepScrim:
            gradient(strong: 0.92, mid: 0.62)
        case .strip:
            // Opaque, so contrast stops depending on the photo entirely. This
            // is the step Reduce Transparency and a blown out frame both land on.
            Color.black.opacity(0.96).frame(height: height * 0.55)
        }
    }

    private func gradient(strong: Double, mid: Double) -> some View {
        LinearGradient(
            stops: [
                .init(color: .black.opacity(strong), location: 0),
                .init(color: .black.opacity(mid), location: 0.45),
                .init(color: .clear, location: 1)
            ],
            startPoint: edge == .bottom ? .bottom : .top,
            endPoint: edge == .bottom ? .top : .bottom
        )
        .frame(height: height)
    }
}

extension View {
    /// Anchors a scrim to one edge of the frame without disturbing layout.
    func mirrorScrim(
        _ protection: MirrorLegibility.Protection,
        height: CGFloat = 200,
        edge: Edge = .bottom
    ) -> some View {
        overlay(alignment: edge == .bottom ? .bottom : .top) {
            MirrorScrim(protection: protection, height: height, edge: edge)
                .allowsHitTesting(false)
        }
    }
}
