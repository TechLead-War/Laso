import XCTest
import SwiftUI
@testable import Laso

/// Renders every Daily Mirror template through the same ImageRenderer path the
/// export uses.
///
/// A template that compiles is not a template that draws: a wrong gate, an
/// empty archive slice or a layout that pushes itself off the frame all build
/// cleanly and produce nothing. This walks the whole set with a full payload
/// and fails on any that comes back blank.
@MainActor
final class MirrorTemplateRenderTests: XCTestCase {

    /// Written to the temp directory so a failing render can be looked at
    /// rather than guessed about. Printed once at the end of the run.
    private static let outputDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("MirrorTemplateRenders", isDirectory: true)

    override class func setUp() {
        try? FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
    }

    func testEveryTemplateDrawsSomething() throws {
        let photo = Self.portrait(size: CGSize(width: 390, height: 520), warm: true)
        let payload = Self.fullPayload
        let archive = Self.archiveSlice(photo: photo)

        var blank: [String] = []

        for template in MirrorTemplate.allCases where template != .clean {
            let rendered = MirrorPhotoRenderer.render(
                photo: photo,
                template: template,
                payload: payload,
                analysis: Self.analysis,
                archive: archive,
                personMask: Self.mask(size: photo.size)
            )

            let url = Self.outputDirectory.appendingPathComponent("\(template.rawValue).png")
            try? rendered.pngData()?.write(to: url)

            // "Drew something" means the overlay changed the picture. Comparing
            // against the source photo catches the real failure mode, which is
            // a template that gates itself off and silently returns the photo
            // untouched.
            if !Self.differs(rendered, from: photo) { blank.append(template.rawValue) }
        }

        print("Mirror template renders written to: \(Self.outputDirectory.path)")
        XCTAssertTrue(blank.isEmpty, "These templates drew nothing over the photo: \(blank.joined(separator: ", "))")
    }

    /// Clean is the one template that must leave the photo exactly as it is.
    func testCleanLeavesThePhotoAlone() {
        let photo = Self.portrait(size: CGSize(width: 390, height: 520), warm: false)
        let rendered = MirrorPhotoRenderer.render(photo: photo, template: .clean, payload: Self.fullPayload)
        XCTAssertFalse(Self.differs(rendered, from: photo))
    }

    /// The gates are what stop an empty frame reaching the picker, so they are
    /// worth a test of their own.
    func testTemplatesGateOnMissingData() {
        let empty = MirrorPayload.empty
        let noArchive = MirrorTemplate.ArchiveFacts.none
        let offered = MirrorTemplate.available(payload: empty, archive: noArchive)

        XCTAssertTrue(offered.contains(.oneWord), "One Word has a no data row and must always be offered")
        XCTAssertTrue(offered.contains(.clean))
        XCTAssertFalse(offered.contains(.number), "A score template cannot be offered with no score")
        XCTAssertFalse(offered.contains(.horizon), "Horizon needs a run of history")
        XCTAssertFalse(offered.contains(.thenAndNow), "Then and Now needs a second photo")
        XCTAssertFalse(offered.contains(.landmark), "Landmark is not a day the user can pick")
    }

    /// A low day must never be answered with a red number on someone's face.
    func testHardDaySuggestsAQuietTemplate() {
        var payload = MirrorPayload.empty
        payload.score = 31
        let suggestion = MirrorTemplate.suggested(
            payload: payload,
            archive: .none,
            houseLook: .number,
            lighting: .easy
        )
        XCTAssertEqual(suggestion, .oneWord)
    }

    /// A frame the ladder cannot protect with a gradient falls to the template
    /// whose contrast does not depend on the photo.
    func testHostileLightingSuggestsTheOpaqueTemplate() {
        var payload = MirrorPayload.empty
        payload.score = 74
        payload.sleepHours = 7.4
        let suggestion = MirrorTemplate.suggested(
            payload: payload,
            archive: .none,
            houseLook: .number,
            lighting: .hostile
        )
        XCTAssertEqual(suggestion, .slip)
    }

    /// The ladder must climb as the frame gets brighter and more uneven.
    func testProtectionLadderClimbsWithBrightness() {
        let block = CGRect(x: 0, y: 0.7, width: 1, height: 0.3)
        let dark = MirrorLegibility.Analysis(face: nil, cells: Array(repeating: 0.05, count: 36))
        let bright = MirrorLegibility.Analysis(face: nil, cells: Array(repeating: 0.85, count: 36))
        var mixedCells = Array(repeating: 0.05, count: 36)
        for index in 30..<36 { mixedCells[index] = 0.95 }
        let uneven = MirrorLegibility.Analysis(face: nil, cells: mixedCells)

        XCTAssertEqual(MirrorLegibility.protection(for: block, analysis: dark, largeType: false), .none)
        XCTAssertEqual(MirrorLegibility.protection(for: block, analysis: bright, largeType: false), .strip)
        XCTAssertEqual(MirrorLegibility.protection(for: block, analysis: uneven, largeType: false), .strip)
        // No measurement means no confidence, so it must not return .none.
        XCTAssertEqual(MirrorLegibility.protection(for: block, analysis: .unknown, largeType: false), .scrim)
    }

    /// The index on an existing user's phone was written before templates were
    /// stored. If the new Meta cannot decode it, every one of their photos
    /// silently loses its score and its streak, so this is the one migration
    /// that has to be proven rather than assumed.
    func testLegacyIndexStillDecodes() throws {
        let legacy = #"{"2026-08-05":{"score":68,"streak":99},"2026-08-06":{"score":74,"streak":100}}"#
        let decoded = try JSONDecoder().decode(
            [String: MirrorPhotoStore.Meta].self,
            from: Data(legacy.utf8)
        )

        XCTAssertEqual(decoded.count, 2)
        let today = try XCTUnwrap(decoded["2026-08-06"])
        XCTAssertEqual(today.score, 74)
        XCTAssertEqual(today.streak, 100)
        XCTAssertTrue(today.isBaked, "A photo with no stored template already carries one in its pixels")
        XCTAssertNil(today.resolvedTemplate)
        XCTAssertNil(today.payload)
    }

    /// And the new shape has to survive its own round trip, including the
    /// payload, or a photo saved today reads back as a legacy one tomorrow.
    func testNewMetaRoundTrips() throws {
        let meta = MirrorPhotoStore.Meta(
            score: 74, streak: 100, template: MirrorTemplate.horizon.rawValue, payload: Self.fullPayload
        )
        let data = try JSONEncoder().encode(meta)
        let back = try JSONDecoder().decode(MirrorPhotoStore.Meta.self, from: data)

        XCTAssertFalse(back.isBaked)
        XCTAssertEqual(back.resolvedTemplate, .horizon)
        XCTAssertEqual(back.payload?.scoreHistory.count, 30)
        XCTAssertEqual(back.payload?.sleepStages.count, 18)
    }

    /// An overlay written by a future version must not take a photo down with
    /// it: an unknown template reads back as no template rather than a crash.
    func testUnknownTemplateDegradesToNoOverlay() throws {
        let future = #"{"score":74,"streak":100,"template":"somethingWeShipNextYear"}"#
        let meta = try JSONDecoder().decode(MirrorPhotoStore.Meta.self, from: Data(future.utf8))
        XCTAssertNil(meta.resolvedTemplate)
        XCTAssertEqual(meta.score, 74)
    }

    // MARK: - Fixtures

    private static let analysis = MirrorLegibility.Analysis(
        face: CGRect(x: 0.3, y: 0.22, width: 0.4, height: 0.34),
        cells: (0..<36).map { 0.18 + Double($0 % 6) * 0.04 }
    )

    private static var fullPayload: MirrorPayload {
        var payload = MirrorPayload.empty
        payload.date = Date(timeIntervalSince1970: 1_785_974_400)
        payload.streak = 100
        payload.captureCount = 137
        payload.daysSinceFirst = 212
        payload.score = 74
        payload.scoreConfidence = 82
        payload.sleepHours = 7.4
        payload.deepMinutes = 63
        payload.remMinutes = 92
        payload.debtHours = 1.2
        payload.vitalityAge = 31
        payload.chronologicalAge = 34
        payload.strain = 12.4
        payload.restingHeartRate = 54
        payload.hrv = 48
        payload.sentence = "Your body clock slipped forty eight minutes."
        payload.actionLine = "You walked after dinner. Recovery moved six points overnight."
        payload.scoreHistory = [58, 61, 55, 63, 67, 70, 66, 64, 72, 69,
                                71, 68, 74, 70, 66, 73, 77, 75, 72, 70,
                                68, 74, 79, 76, 73, 71, 75, 78, 76, 74]
        payload.sleepStages = [
            .init(level: 0, minutes: 5), .init(level: 2, minutes: 18), .init(level: 3, minutes: 30),
            .init(level: 2, minutes: 26), .init(level: 1, minutes: 16), .init(level: 2, minutes: 32),
            .init(level: 3, minutes: 21), .init(level: 2, minutes: 30), .init(level: 1, minutes: 28),
            .init(level: 2, minutes: 34), .init(level: 3, minutes: 12), .init(level: 2, minutes: 36),
            .init(level: 1, minutes: 30), .init(level: 2, minutes: 40), .init(level: 0, minutes: 4),
            .init(level: 2, minutes: 32), .init(level: 1, minutes: 18), .init(level: 2, minutes: 32)
        ]
        return payload
    }

    private static func archiveSlice(photo: UIImage) -> MirrorArchiveSlice {
        func day(_ offset: Int) -> MirrorArchiveDay {
            MirrorArchiveDay(
                id: "day-\(offset)",
                date: Date(timeIntervalSince1970: 1_785_974_400 - Double(offset) * 86_400),
                score: 55 + (offset * 7) % 40,
                image: photo
            )
        }
        var slice = MirrorArchiveSlice()
        slice.week = (0..<7).reversed().map(day)
        slice.sheet = (0..<9).reversed().map(day)
        slice.first = day(212)
        return slice
    }

    /// A stand in for a front camera frame: a warm or cool field with a darker
    /// oval where a head would be, so an overlay drawn over it is judged
    /// against something with real tonal range rather than flat grey.
    private static func portrait(size: CGSize, warm: Bool) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { context in
            let cg = context.cgContext
            let space = CGColorSpaceCreateDeviceRGB()
            let top: [CGFloat] = warm ? [0.79, 0.72, 0.62, 1.0] : [0.42, 0.49, 0.56, 1.0]
            let bottom: [CGFloat] = warm ? [0.20, 0.17, 0.14, 1.0] : [0.09, 0.11, 0.13, 1.0]
            if let gradient = CGGradient(colorSpace: space,
                                         colorComponents: top + bottom,
                                         locations: [0, 1], count: 2) {
                cg.drawLinearGradient(gradient, start: .zero,
                                      end: CGPoint(x: 0, y: size.height), options: [])
            }
            cg.setFillColor(red: 0.16, green: 0.12, blue: 0.09, alpha: 0.85)
            cg.fillEllipse(in: CGRect(x: size.width * 0.30, y: size.height * 0.20,
                                      width: size.width * 0.40, height: size.height * 0.30))
        }
    }

    /// White where the subject is, black elsewhere, which is the shape Vision
    /// hands back for a person segmentation.
    ///
    /// Head and shoulders only, and deliberately narrow: a mask that covered
    /// the whole lower frame would hide Behind You's numeral completely and
    /// the test would still pass, which is exactly the trap this fixture has
    /// to avoid.
    private static func mask(size: CGSize) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { context in
            let cg = context.cgContext
            cg.setFillColor(UIColor.black.cgColor)
            cg.fill(CGRect(origin: .zero, size: size))
            cg.setFillColor(UIColor.white.cgColor)
            cg.fillEllipse(in: CGRect(x: size.width * 0.32, y: size.height * 0.20,
                                      width: size.width * 0.36, height: size.height * 0.30))
            cg.fillEllipse(in: CGRect(x: size.width * 0.18, y: size.height * 0.52,
                                      width: size.width * 0.64, height: size.height * 0.62))
        }
    }

    /// Behind You is the one template whose whole idea is depth, so a render
    /// that hides the numeral entirely is a failure even though pixels changed.
    func testBehindYouKeepsTheNumeralVisibleBesideTheSubject() throws {
        let photo = Self.portrait(size: CGSize(width: 390, height: 520), warm: false)
        var payload = MirrorPayload.empty
        payload.score = 74
        payload.date = Self.fullPayload.date
        payload.streak = 12

        let rendered = MirrorPhotoRenderer.render(
            photo: photo, template: .behindYou, payload: payload,
            analysis: Self.analysis, personMask: Self.mask(size: photo.size)
        )

        // The numeral straddles the subject, so the frame's outer columns at
        // the numeral's height must be brighter than the same band of the bare
        // photo. If the cutout swallowed the glyph, they are identical.
        let band = CGRect(x: 0, y: 0.24, width: 1, height: 0.36)
        XCTAssertGreaterThan(
            Self.meanLuminance(rendered, in: band) - Self.meanLuminance(photo, in: band),
            0.02,
            "Behind You drew no visible numeral beside the subject"
        )
    }

    private static func meanLuminance(_ image: UIImage, in unitRect: CGRect) -> Double {
        guard let pixels = bytes(image) else { return 0 }
        let side = 48
        var total = 0.0
        var count = 0.0
        for row in Int(unitRect.minY * Double(side))..<Int(unitRect.maxY * Double(side)) {
            for column in Int(unitRect.minX * Double(side))..<Int(unitRect.maxX * Double(side)) {
                let index = (row * side + column) * 4
                guard index + 2 < pixels.count else { continue }
                total += (Double(pixels[index]) + Double(pixels[index + 1]) + Double(pixels[index + 2])) / 765.0
                count += 1
            }
        }
        return count > 0 ? total / count : 0
    }

    /// True when the two images differ anywhere. Compares raw bytes at a small
    /// fixed size: exact pixel equality on the full resolution pair would be
    /// slower and no more informative.
    private static func differs(_ a: UIImage, from b: UIImage) -> Bool {
        guard let left = bytes(a), let right = bytes(b) else { return true }
        return left != right
    }

    private static func bytes(_ image: UIImage) -> [UInt8]? {
        let side = 48
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        guard let cgImage = image.cgImage,
              let context = CGContext(
                data: &pixels, width: side, height: side, bitsPerComponent: 8,
                bytesPerRow: side * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: side, height: side))
        return pixels
    }
}
