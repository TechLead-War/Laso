import SwiftUI
import UIKit

// MARK: - Behind You

/// The score set behind the subject, so the number reads as part of the room
/// rather than a sticker on the glass.
struct MirrorBehindYou: View {
    let payload: MirrorPayload
    var photo: UIImage?
    var mask: UIImage?

    private var hasCutout: Bool { photo != nil && mask != nil }

    var body: some View {
        if let score = payload.score {
            ZStack {
                numeral(score)
                cutout
                fade
                footer(score)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            EmptyView()
        }
    }

    private func numeral(_ score: Int) -> some View {
        VStack(spacing: 0) {
            // With a cutout the glyph sits high so the person crosses its middle.
            // Without one it drops to the floor of the frame, because a 230 point
            // number over an uncut photo would land straight on the face.
            if hasCutout {
                Spacer().frame(height: 110)
            } else {
                Spacer(minLength: 0)
            }
            Text("\(score)")
                .font(MirrorType.numeral(230, weight: .heavy))
                .tracking(-12)
                .foregroundStyle(.white.opacity(hasCutout ? 0.93 : 0.30))
                // The only thing standing between a white glyph and a white wall.
                // No analysis reaches this template, so there is no measured scrim
                // to fall back on and this shadow has to carry the contrast alone.
                .shadow(color: .black.opacity(0.4), radius: 18)
            if hasCutout {
                Spacer(minLength: 0)
            } else {
                Spacer().frame(height: 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var cutout: some View {
        if let photo = photo, let subject = mask {
            Image(uiImage: photo)
                .resizable()
                .scaledToFill()
                .mask {
                    Image(uiImage: subject)
                        .resizable()
                        .scaledToFill()
                        // Vision returns the segmentation as a grayscale buffer
                        // with no alpha, and SwiftUI's mask reads alpha only.
                        // Without this the mask is opaque everywhere, the whole
                        // photo is redrawn on top, and the numeral behind it
                        // disappears completely.
                        .luminanceToAlpha()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .allowsHitTesting(false)
        }
    }

    private var fade: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            LinearGradient(
                colors: [.black.opacity(0.62), .clear],
                startPoint: .bottom,
                endPoint: .top
            )
            .frame(height: 130)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }

    private func footer(_ score: Int) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            HStack(spacing: 0) {
                MirrorLabel(MirrorFormat.stamp(payload.date))
                Spacer(minLength: 0)
                MirrorLabel(trailing(score), opacity: 0.6)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 22)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Confidence outranks the band word: on a morning the lock is unsure, how
    /// sure it is says more than what it says.
    private func trailing(_ score: Int) -> String {
        if let confidence = payload.scoreConfidence {
            return Copy.Mirror.confidenceSure(confidence)
        }
        return DS.scoreLabel(score).uppercased() + " · " + Copy.Mirror.dayNumber(payload.streak)
    }
}

// MARK: - Newsprint

/// The photo screened down to halftone dots and set like a front page.
struct MirrorNewsprint: View {
    let payload: MirrorPayload
    var photo: UIImage?

    private static let paper = Color(red: 0.957, green: 0.949, blue: 0.929)
    private static let ink = Color(red: 0.078, green: 0.067, blue: 0.055)
    private static let inkGrey = Color(red: 0.29, green: 0.267, blue: 0.235)
    private static let slabInk = Color(red: 0.043, green: 0.043, blue: 0.051)

    private static let dotPitch: CGFloat = 4
    private static let dotRadius: CGFloat = 1.15

    var body: some View {
        if let photo = photo, let score = payload.score {
            // No scrim anywhere: the masthead and the slab are opaque, so nothing
            // here reads against the photo and the legibility ladder has nothing
            // to decide.
            ZStack {
                screened(photo)
                VStack(spacing: 0) {
                    masthead
                    Spacer(minLength: 0)
                }
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    slab(score)
                        .padding(.horizontal, 18)
                        .padding(.bottom, 20)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            EmptyView()
        }
    }

    /// Rebuilding the photo at a contrast we choose, rather than the one the room
    /// gave us, is what makes this the safe look for hopeless lighting.
    private func screened(_ photo: UIImage) -> some View {
        Image(uiImage: photo)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .saturation(0)
            .contrast(1.9)
            .brightness(0.03)
            .overlay { dotScreen }
    }

    private var dotScreen: some View {
        Rectangle()
            .fill(.black)
            .opacity(0.62)
            .mask {
                Canvas { context, size in
                    // Every dot goes into one Path and is filled once. Stamping
                    // circles one call at a time is thousands of draws on a full
                    // frame, and this has to render inside an ImageRenderer pass.
                    var dots = Path()
                    var y: CGFloat = 0
                    while y < size.height {
                        var x: CGFloat = 0
                        while x < size.width {
                            dots.addEllipse(in: CGRect(
                                x: x - Self.dotRadius,
                                y: y - Self.dotRadius,
                                width: Self.dotRadius * 2,
                                height: Self.dotRadius * 2
                            ))
                            x += Self.dotPitch
                        }
                        y += Self.dotPitch
                    }
                    context.fill(dots, with: .color(.white))
                }
            }
            .allowsHitTesting(false)
    }

    private var masthead: some View {
        VStack(spacing: 0) {
            Text(Copy.Mirror.masthead)
                .font(MirrorType.serif(26))
                .tracking(1.3)
                .foregroundStyle(Self.ink)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 8)
            Rectangle()
                .fill(Self.ink)
                .frame(height: 1.5)
            HStack(spacing: 0) {
                MirrorLabel(MirrorFormat.stamp(payload.date), size: 8.5, opacity: 1, colour: Self.inkGrey)
                Spacer(minLength: 0)
                MirrorLabel(Copy.Mirror.issueNumber(payload.streak), size: 8.5, opacity: 1, colour: Self.inkGrey)
            }
            .padding(.top, 7)
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 9)
        .frame(maxWidth: .infinity)
        .background(Self.paper)
    }

    private func slab(_ score: Int) -> some View {
        HStack(spacing: 14) {
            Text("\(score)")
                .font(MirrorType.numeral(88, weight: .heavy))
                .tracking(-3)
                .foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 8) {
                MirrorLabel(
                    Copy.Mirror.labelReady + " · " + DS.scoreLabel(score).uppercased(),
                    size: 10,
                    opacity: 1
                )
                if let sentence = payload.sentence {
                    Text(sentence)
                        .font(MirrorType.serif(15))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Self.slabInk)
    }
}

// MARK: - Nineteen Ninety Eight

/// A camcorder date stamp in one dead corner and one health number in the other.
struct MirrorNineties: View {
    let payload: MirrorPayload

    private static let grade = Color(red: 1.0, green: 0.541, blue: 0.239)
    private static let glow = Color(red: 1.0, green: 0.478, blue: 0.094)

    var body: some View {
        if let score = payload.score {
            // No scrim: the type is emissive, tiny, and in the two deadest corners
            // of the frame, which is exactly why the original survived twenty years
            // of holiday photos.
            ZStack {
                Self.grade.opacity(0.10).blendMode(.softLight)
                bottomFade
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    HStack(alignment: .bottom, spacing: 0) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            stamp("\(score)")
                            stamp(Copy.Mirror.labelReady, size: 12)
                        }
                        Spacer(minLength: 0)
                        if let stamped = stampedDate {
                            stamp(stamped)
                        }
                    }
                    .padding(22)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            EmptyView()
        }
    }

    /// Drawn over the whole frame with the stops placed so it is still clear at
    /// the 60 percent mark. Same pixels as a 40 percent tall gradient, without
    /// needing to measure the frame to get the height.
    private var bottomFade: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .clear, location: 0.6),
                .init(color: .black.opacity(0.4), location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .allowsHitTesting(false)
    }

    /// The kit's monospaced voice is fixed at semibold, and a camcorder burn in
    /// is bold or it is not a camcorder burn in, so this one type is built here.
    private func stamp(_ text: String, size: CGFloat = 24) -> some View {
        Text(text)
            .font(.system(size: size, weight: .bold, design: .monospaced))
            .tracking(1.4)
            .foregroundStyle(Self.glow)
            .shadow(color: Self.glow.opacity(0.75), radius: 9)
    }

    /// Year, month and day as the camera firmware wrote them. This is a machine
    /// stamp shape rather than English, so it is built from digits here instead
    /// of coming out of the copy table.
    private var stampedDate: String? {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: payload.date)
        guard let year = parts.year, let month = parts.month, let day = parts.day else { return nil }
        return String(format: "'%02d %02d %02d", year % 100, month, day)
    }
}
