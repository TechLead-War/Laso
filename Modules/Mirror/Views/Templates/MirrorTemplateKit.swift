import SwiftUI
import UIKit

/// The parts every Daily Mirror template is built from.
///
/// Templates have two voices and no others: a rounded numeral for values and a
/// wide tracked monospaced cap for labels. Keeping both here is what stops
/// eighteen templates drifting into eighteen typefaces.
enum MirrorType {
    static func numeral(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded).monospacedDigit()
    }

    static func label(_ size: CGFloat = 9.5) -> Font {
        .system(size: size, weight: .semibold, design: .monospaced)
    }

    static func serif(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    /// Tracking for label caps, as a fraction of the size. Wide enough to read
    /// as an instrument marking rather than as shouting.
    static let labelTracking: CGFloat = 0.18
}

/// A wide tracked monospaced cap. The quietest thing a template can say.
struct MirrorLabel: View {
    let text: String
    var size: CGFloat = 9.5
    var opacity: Double = 0.82
    var colour: Color = .white

    init(_ text: String, size: CGFloat = 9.5, opacity: Double = 0.82, colour: Color = .white) {
        self.text = text
        self.size = size
        self.opacity = opacity
        self.colour = colour
    }

    var body: some View {
        Text(text)
            .font(MirrorType.label(size))
            .tracking(size * MirrorType.labelTracking)
            .foregroundStyle(colour.opacity(opacity))
    }
}

/// A label over a value, the unit every readout rail is made of.
struct MirrorReadout: View {
    let name: String
    let value: String
    var tint: Color = .white
    var valueSize: CGFloat = 17

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            MirrorLabel(name, size: 8.5, opacity: 0.6)
            Text(value)
                .font(MirrorType.numeral(valueSize))
                .foregroundStyle(tint)
        }
    }
}

/// Formatting shared across templates, so a date never appears in two shapes.
enum MirrorFormat {

    static func stamp(_ date: Date) -> String {
        date.formatted(.dateTime.day(.twoDigits).month(.abbreviated).year()).uppercased()
    }

    static func clock(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened).uppercased()
    }

    static func longDay(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.wide).year())
    }

    static func shortDay(_ date: Date) -> String {
        date.formatted(.dateTime.day(.twoDigits).month(.abbreviated)).uppercased()
    }

    /// Hours and minutes from a decimal hour count, as "7h 24m".
    static func duration(hours: Double) -> String {
        let total = Int((hours * 60).rounded())
        return "\(total / 60)h \(total % 60)m"
    }

    static func minutes(_ value: Double) -> String {
        "\(Int(value.rounded()))m"
    }

    /// Compact form for a narrow rail, as "7h24".
    static func tightDuration(hours: Double) -> String {
        let total = Int((hours * 60).rounded())
        return "\(total / 60)h\(String(format: "%02d", total % 60))"
    }
}

/// Corner brackets, the viewfinder marking Field Notes and Contact Sheet share.
struct MirrorCorners: View {
    var inset: CGFloat = 13
    var arm: CGFloat = 15
    var opacity: Double = 0.55

    var body: some View {
        ZStack {
            corner(.topLeading)
            corner(.topTrailing)
            corner(.bottomLeading)
            corner(.bottomTrailing)
        }
        .padding(inset)
    }

    private func corner(_ alignment: Alignment) -> some View {
        let isTop = alignment == .topLeading || alignment == .topTrailing
        let isLeading = alignment == .topLeading || alignment == .bottomLeading
        return Path { path in
            path.move(to: CGPoint(x: isLeading ? 0 : arm, y: isTop ? arm : 0))
            path.addLine(to: CGPoint(x: isLeading ? 0 : arm, y: isTop ? 0 : arm))
            path.addLine(to: CGPoint(x: isLeading ? arm : 0, y: isTop ? 0 : arm))
        }
        .stroke(.white.opacity(opacity), lineWidth: 1.2)
        .frame(width: arm, height: arm)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
    }
}

/// One photo out of the archive, resolved on the main actor so template views
/// stay pure and can be previewed without touching disk.
struct MirrorArchiveDay: Identifiable, Equatable {
    let id: String
    let date: Date
    let score: Int?
    let image: UIImage?

    /// UIImage is not Equatable, and comparing decoded pixels to decide whether
    /// a view needs redrawing would be far more expensive than redrawing it.
    /// The day key plus the score is the whole identity of an archive cell.
    static func == (a: MirrorArchiveDay, b: MirrorArchiveDay) -> Bool {
        a.id == b.id && a.score == b.score && (a.image == nil) == (b.image == nil)
    }
}

/// The slice of the archive the multi photo templates need. Built once per
/// render rather than read piecemeal, so a gallery scroll cannot turn into one
/// disk read per cell per frame.
struct MirrorArchiveSlice: Equatable {
    /// Up to seven days ending on the photo's own day, oldest first.
    var week: [MirrorArchiveDay] = []
    /// Up to nine days ending on the photo's own day, oldest first.
    var sheet: [MirrorArchiveDay] = []
    var first: MirrorArchiveDay?

    static let empty = MirrorArchiveSlice()

    /// What a template actually needs, so the caller can skip the disk work for
    /// the fifteen templates that never look at a second photo.
    enum Need {
        case none, week, sheet, first
    }

    @MainActor
    static func build(for need: Need, endingOn date: Date, store: MirrorPhotoStore = .shared) -> MirrorArchiveSlice {
        var slice = MirrorArchiveSlice()
        func day(_ target: Date, thumbnail: Bool) -> MirrorArchiveDay? {
            guard store.hasPhoto(on: target) else { return nil }
            return MirrorArchiveDay(
                id: MirrorPhotoStore.dayKey(for: target),
                date: target,
                score: store.meta(on: target)?.score,
                image: thumbnail ? store.thumbnail(on: target) : store.image(on: target)
            )
        }
        switch need {
        case .none:
            break
        case .week:
            slice.week = (0..<7).reversed().compactMap { day(date.daysAgo($0), thumbnail: true) }
        case .sheet:
            slice.sheet = (0..<9).reversed().compactMap { day(date.daysAgo($0), thumbnail: true) }
        case .first:
            slice.first = store.allDays.first.flatMap { day($0, thumbnail: true) }
        }
        return slice
    }
}

extension MirrorTemplate {
    /// Which archive read this template needs before it can draw.
    var archiveNeed: MirrorArchiveSlice.Need {
        switch self {
        case .thisWeek:     return .week
        case .contactSheet: return .sheet
        case .thenAndNow:   return .first
        default:            return .none
        }
    }
}

// MARK: - The dispatcher

/// Draws the chosen template over a photo.
///
/// Always laid out in a 390 point wide design space, which `MirrorPhotoFrame`
/// scales to whatever size it is shown at. Every size in a template is
/// therefore a real point value, the same one that reaches the exported JPEG.
struct MirrorOverlay: View {
    let template: MirrorTemplate
    let payload: MirrorPayload
    var analysis: MirrorLegibility.Analysis = .unknown
    var archive: MirrorArchiveSlice = .empty
    /// The photo itself, for the three templates that compose with it rather
    /// than sit on top of it.
    var photo: UIImage?
    /// Subject cutout, used by Behind You to put the numeral behind the person.
    /// Nil is a supported outcome, not a failure: the template falls back.
    var personMask: UIImage?

    var body: some View {
        switch template {
        case .clean:        EmptyView()
        case .fieldNotes:   MirrorFieldNotes(payload: payload, analysis: analysis)
        case .number:       MirrorNumber(payload: payload, analysis: analysis)
        case .oneWord:      MirrorOneWord(payload: payload)
        case .behindYou:    MirrorBehindYou(payload: payload, photo: photo, mask: personMask)
        case .horizon:      MirrorHorizon(payload: payload)
        case .night:        MirrorNight(payload: payload, analysis: analysis)
        case .bodyAge:      MirrorBodyAge(payload: payload, analysis: analysis)
        case .slip:         MirrorSlip(payload: payload)
        case .chin:         MirrorChin(payload: payload, photo: photo)
        case .newsprint:    MirrorNewsprint(payload: payload, photo: photo)
        case .nineties:     MirrorNineties(payload: payload)
        case .thisWeek:     MirrorThisWeek(payload: payload, archive: archive, analysis: analysis)
        case .thenAndNow:   MirrorThenAndNow(payload: payload, archive: archive)
        case .contactSheet: MirrorContactSheet(payload: payload, archive: archive)
        case .sentence:     MirrorSentence(payload: payload)
        case .claim:        MirrorClaim(payload: payload, analysis: analysis)
        case .landmark:     MirrorLandmark(payload: payload)
        }
    }

    /// These three compose the photo into their own layout, so the frame must
    /// not also draw it full bleed underneath them.
    static func drawsOwnPhoto(_ template: MirrorTemplate) -> Bool {
        switch template {
        case .contactSheet, .chin, .newsprint: return true
        default: return false
        }
    }
}
