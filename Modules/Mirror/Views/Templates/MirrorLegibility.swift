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
        /// Mean luminance, 0 to 1, of each cell of a `gridSize` square grid,
        /// row major from the top left.
        var cells: [Double]

        static let gridSize = 6
        static let unknown = Analysis(cells: [])

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

    /// The step for the small labels along the top edge. Capped below the
    /// strip: a solid bar across the top of a portrait reads as a crop, so a
    /// bright ceiling gets the deep gradient and nothing heavier.
    static func topProtection(for rect: CGRect, analysis: Analysis) -> Protection {
        min(protection(for: rect, analysis: analysis, largeType: false), .deepScrim)
    }

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

    /// A luminance grid for a captured frame. Runs off the main actor so the
    /// caller can keep the photo on screen while it waits. Expects an upright
    /// photo (see `upright`): the grid reads raw pixels, and a camera frame
    /// still carrying its rotation flag would be measured on its side.
    static func analyse(_ photo: UIImage) async -> Analysis {
        guard let cgImage = photo.cgImage else { return .unknown }
        return await Task.detached(priority: .userInitiated) {
            Analysis(cells: luminanceGrid(cgImage, columns: Analysis.gridSize, rows: Analysis.gridSize))
        }.value
    }

    /// The photo with its pixels rotated the way it is displayed, so every
    /// pixel reader downstream (the luminance grid, the person mask, the
    /// halftone) agrees with what `Image(uiImage:)` shows. A camera capture
    /// arrives with its rotation in a flag rather than in its pixels; Vision
    /// and CoreGraphics read the pixels, SwiftUI honours the flag, and the
    /// cutout came back sideways against the face it was meant to cover.
    static func upright(_ photo: UIImage) -> UIImage {
        guard photo.imageOrientation != .up else { return photo }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: photo.size, format: format).image { _ in
            photo.draw(in: CGRect(origin: .zero, size: photo.size))
        }
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

    /// Mean luminance per cell of a `columns` by `rows` grid, row major from
    /// the top left, read from one small grayscale draw so the hardware does
    /// the averaging. With `aspect` (width over height) the image is first
    /// cropped to fill that shape, matching a `scaledToFill` frame.
    static func luminanceGrid(_ image: CGImage, columns: Int, rows: Int, filling aspect: CGFloat? = nil) -> [Double] {
        guard columns > 0, rows > 0 else { return [] }
        var source = image
        if let aspect, aspect > 0 {
            let width = CGFloat(image.width)
            let height = CGFloat(image.height)
            let cropWidth = min(width, height * aspect)
            let cropHeight = min(height, width / aspect)
            let crop = CGRect(x: (width - cropWidth) / 2, y: (height - cropHeight) / 2,
                              width: cropWidth, height: cropHeight).integral
            if let cropped = image.cropping(to: crop) { source = cropped }
        }
        var pixels = [UInt8](repeating: 0, count: columns * rows)
        guard let context = CGContext(
            data: &pixels, width: columns, height: rows, bitsPerComponent: 8,
            bytesPerRow: columns, space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return [] }
        context.interpolationQuality = .medium
        context.draw(source, in: CGRect(x: 0, y: 0, width: columns, height: rows))
        // CGContext origin is bottom left, so rows come back upside down
        // relative to the unit rects callers hand in.
        return (0..<rows).reversed().flatMap { row in
            (0..<columns).map { Double(pixels[row * columns + $0]) / 255.0 }
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

