import SwiftUI
import UIKit

/// One press for both printed objects, so the ink and the paper can never drift
/// apart between them.
private enum MirrorPrint {
    static let ink = Color(red: 0.078, green: 0.067, blue: 0.055)
    static let slipStock = Color(red: 0.965, green: 0.953, blue: 0.925)
    static let slipMuted = Color(red: 0.42, green: 0.392, blue: 0.349)
    static let slipRule = Color(red: 0.655, green: 0.62, blue: 0.565)
    static let chinStock = Color(red: 0.949, green: 0.937, blue: 0.910)
    static let chinMuted = Color(red: 0.478, green: 0.447, blue: 0.392)
    static let chinSoftInk = Color(red: 0.173, green: 0.153, blue: 0.129)
    /// Punctuation between two stamps, which is why it does not come from
    /// `Copy.Mirror`: there is nothing here to translate.
    static let dot = " · "
}

/// One horizontal line, stroked wide for the receipt rules and finely for the
/// leader that runs between a label and its value.
private struct MirrorRule: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

/// The day printed as a receipt and dropped into the frame.
///
/// No scrim ladder: the slip is opaque stock, so its contrast is the paper's
/// and not the photo's. That is exactly why the picker falls back to it when
/// the lighting is hostile.
struct MirrorSlip: View {
    let payload: MirrorPayload

    /// A thermal printer has one face at one weight. Borrowing the kit's
    /// semibold label voice for every line would make the rows heavier than
    /// the total they add up to.
    private static let face = Font.system(size: 10, design: .monospaced)
    private static let faceTotal = Font.system(size: 12, weight: .bold, design: .monospaced)

    var body: some View {
        if payload.hasScore || payload.hasSleep {
            slip
                .frame(width: 236)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(MirrorPrint.slipStock)
                        .shadow(color: .black.opacity(0.5), radius: 12, y: 6)
                )
                .rotationEffect(.degrees(-1.8))
                .padding(.leading, 26)
                .padding(.top, 150)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } else {
            // A receipt with one line on it is not a receipt.
            EmptyView()
        }
    }

    private var slip: some View {
        VStack(spacing: 9) {
            Text(Copy.Mirror.masthead.uppercased())
                .font(Self.face.weight(.bold))
                .tracking(1.8)
                .foregroundStyle(MirrorPrint.ink)

            Text(MirrorFormat.stamp(payload.date) + MirrorPrint.dot + MirrorFormat.clock(payload.date))
                .font(Self.face)
                .tracking(1.0)
                .foregroundStyle(MirrorPrint.slipMuted)

            rule(dash: [3, 3])

            VStack(spacing: 5) {
                if let score = payload.score {
                    row(Copy.Mirror.labelReady, String(score))
                }
                if let hours = payload.sleepHours {
                    row(Copy.Mirror.labelSleep, MirrorFormat.duration(hours: hours))
                }
                if let deep = payload.deepMinutes {
                    row(Copy.Mirror.labelDeep, MirrorFormat.minutes(deep))
                }
                if let strain = payload.strain {
                    row(Copy.Mirror.labelStrain, strain.formatted(.number.precision(.fractionLength(1))))
                }
                if let resting = payload.restingHeartRate {
                    row(Copy.Mirror.labelResting, String(resting))
                }
                if let hrv = payload.hrv {
                    row(Copy.Mirror.labelHrv, String(hrv))
                }
            }

            rule(dash: [3, 3])

            total

            barcode

            MirrorLabel(Copy.Mirror.labelKeptHere, size: 8, opacity: 1, colour: MirrorPrint.slipMuted)
        }
        .padding(16)
    }

    private func rule(dash: [CGFloat]) -> some View {
        MirrorRule()
            .stroke(MirrorPrint.slipRule, style: StrokeStyle(lineWidth: 1, dash: dash))
            .frame(height: 1)
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(Self.face)
            rule(dash: [1, 3])
            Text(value)
                .font(Self.face.weight(.bold))
        }
        .foregroundStyle(MirrorPrint.ink)
        .frame(maxWidth: .infinity)
    }

    /// The day comes back from Copy as one string, and a receipt total needs the
    /// word at one edge and the number at the other. Splitting it here beats a
    /// second copy key that could drift out of step with this one.
    @ViewBuilder
    private var total: some View {
        let text = Copy.Mirror.dayNumber(payload.streak)
        if let space = text.lastIndex(of: " ") {
            HStack(spacing: 6) {
                MirrorLabel(String(text[..<space]), size: 10, opacity: 1, colour: MirrorPrint.ink)
                Spacer(minLength: 6)
                Text(String(text[text.index(after: space)...]))
                    .font(Self.faceTotal)
                    .foregroundStyle(MirrorPrint.ink)
            }
            .frame(maxWidth: .infinity)
        } else {
            MirrorLabel(text, size: 10, opacity: 1, colour: MirrorPrint.ink)
        }
    }

    /// Bar widths come from the index, never from a random source, so the same
    /// day always prints the same slip. A pattern that changed on every redraw
    /// would read as generated rather than printed.
    private var barcode: some View {
        HStack(spacing: 1.5) {
            ForEach(0..<48, id: \.self) { index in
                Rectangle()
                    .fill(MirrorPrint.ink)
                    .frame(width: index % 5 == 0 ? 3 : (index % 3 == 0 ? 2 : 1))
            }
        }
        .frame(height: 18)
    }
}

/// Instant film: the photo inset in a card, with the day written on the white
/// lip below it.
///
/// No scrim ladder here either, because no type is ever drawn over the picture.
/// The card is opaque stock and the photo sits inside it. This template draws
/// the photo itself, so the frame must not also draw it full bleed underneath.
struct MirrorChin: View {
    let payload: MirrorPayload
    var photo: UIImage?

    var body: some View {
        if let photo {
            VStack(spacing: 0) {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    // The flexible frame is what leaves the chin at its own
                    // intrinsic height, so the lip stays about 100 tall
                    // whatever aspect the photo arrived at.
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 2))
                chin
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(MirrorPrint.chinStock)
        } else {
            EmptyView()
        }
    }

    private var chin: some View {
        HStack(alignment: .top, spacing: 16) {
            if let score = payload.score {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(score))
                        .font(MirrorType.numeral(46))
                        .foregroundStyle(MirrorPrint.ink)
                    MirrorLabel(Copy.Mirror.labelReady, size: 8.5, opacity: 1, colour: MirrorPrint.chinMuted)
                }
            }
            VStack(alignment: .leading, spacing: 7) {
                if let caption {
                    Text(caption)
                        .font(MirrorType.serif(13.5, weight: .regular).italic())
                        .foregroundStyle(MirrorPrint.chinSoftInk)
                        .lineLimit(2)
                }
                Text(MirrorFormat.stamp(payload.date) + MirrorPrint.dot + Copy.Mirror.dayNumber(payload.streak))
                    .font(MirrorType.label(8.5))
                    .foregroundStyle(MirrorPrint.chinMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.top, 16)
        .padding(.bottom, 18)
    }

    /// The proof line wins when the day earned one, because it names something
    /// the user did rather than something the app noticed.
    private var caption: String? { payload.actionLine ?? payload.sentence }
}
