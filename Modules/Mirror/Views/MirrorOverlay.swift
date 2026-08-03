import SwiftUI

/// The data filters a Daily Mirror photo can carry. The overlay is baked into
/// the saved JPEG, so what the user picks at capture is what every later
/// surface (replay, Explore, share) shows.
enum MirrorFilter: String, CaseIterable, Identifiable {
    case stamp, ring, bigScore, streak, tint, dateOnly, clean

    var id: String { rawValue }

    var label: String {
        switch self {
        case .stamp:    return Copy.Mirror.filterStamp
        case .ring:     return Copy.Mirror.filterRing
        case .bigScore: return Copy.Mirror.filterBigScore
        case .streak:   return Copy.Mirror.filterStreak
        case .tint:     return Copy.Mirror.filterTint
        case .dateOnly: return Copy.Mirror.filterDateOnly
        case .clean:    return Copy.Mirror.filterClean
        }
    }

    /// Overlays whose whole content is the readiness score. Offering these on a
    /// day with no score would hand the user a chip that draws nothing.
    var requiresScore: Bool {
        switch self {
        case .ring, .bigScore, .tint: return true
        case .stamp, .streak, .dateOnly, .clean: return false
        }
    }

    static func available(hasScore: Bool) -> [MirrorFilter] {
        hasScore ? allCases : allCases.filter { !$0.requiresScore }
    }
}

/// Draws the selected filter over a photo. Sized in the same 390pt design
/// space as the share cards; `MirrorPhotoRenderer` scales it to photo pixels.
struct MirrorOverlay: View {
    let filter: MirrorFilter
    let date: Date
    let score: Int?
    let streak: Int

    var body: some View {
        ZStack {
            switch filter {
            case .stamp:
                stamp
            case .ring:
                ringBadge
            case .bigScore:
                bigScore
            case .tint:
                // Straight frame, no corner radius: the saved JPEG is a full
                // bleed rectangle, so a rounded stroke would clip at the edges.
                Rectangle()
                    .strokeBorder(DS.scoreColor(score ?? 0).opacity(0.9), lineWidth: 10)
            case .streak:
                streakBadge
            case .dateOnly:
                dateChip
            case .clean:
                EmptyView()
            }
        }
    }

    private var stamp: some View {
        VStack {
            Spacer()
            HStack(spacing: DS.space3) {
                if let score {
                    scoreRing(score, diameter: 48, lineWidth: 5, fontSize: 18)
                }

                VStack(alignment: .leading, spacing: 2) {
                    if let score {
                        Text(Copy.Mirror.recoveryScore(score))
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    Text(date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.75))
                }
                Spacer(minLength: 0)
            }
            .padding(DS.space3)
            .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: DS.Radius.lg))
            .padding(DS.space4)
        }
    }

    /// The score alone, top left, for people who want the number without the
    /// date row the stamp carries.
    @ViewBuilder
    private var ringBadge: some View {
        if let score {
            VStack {
                HStack {
                    scoreRing(score, diameter: 64, lineWidth: 6, fontSize: 24)
                        .padding(DS.space3)
                        .background(.black.opacity(0.45), in: Circle())
                    Spacer()
                }
                .padding(DS.space4)
                Spacer()
            }
        }
    }

    /// Score as the loudest thing in the frame. Bottom right so a face in the
    /// centre of the photo stays clear of it.
    @ViewBuilder
    private var bigScore: some View {
        if let score {
            VStack {
                Spacer()
                HStack(alignment: .lastTextBaseline, spacing: DS.space2) {
                    Spacer()
                    Text("\(score)")
                        .font(.system(size: 76, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(DS.scoreColor(score))
                    Text(Copy.Mirror.filterBigScoreUnit)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .shadow(color: .black.opacity(0.5), radius: 8, y: 2)
                .padding(DS.space5)
            }
        }
    }

    /// The quietest overlay: just the day, for photos that should carry a date
    /// and nothing else.
    private var dateChip: some View {
        VStack {
            Spacer()
            HStack {
                Text(date.formatted(.dateTime.day().month(.abbreviated).year()))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, DS.space3)
                    .padding(.vertical, DS.space2)
                    .background(.black.opacity(0.55), in: Capsule())
                Spacer()
            }
            .padding(DS.space4)
        }
    }

    private func scoreRing(_ score: Int, diameter: CGFloat, lineWidth: CGFloat, fontSize: CGFloat) -> some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.3), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: Double(score) / 100.0)
                .stroke(DS.scoreColor(score), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(score)")
                .font(.system(size: fontSize, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
        }
        .frame(width: diameter, height: diameter)
    }

    private var streakBadge: some View {
        VStack {
            HStack {
                Spacer()
                HStack(spacing: DS.space1) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text(Copy.Mirror.streakDays(streak))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, DS.space3)
                .padding(.vertical, DS.space2)
                .background(.black.opacity(0.55), in: Capsule())
            }
            .padding(DS.space4)
            Spacer()
        }
    }
}

/// Bakes the chosen overlay into the photo at the photo's own pixel size, the
/// same ImageRenderer path the share cards already use.
@MainActor
enum MirrorPhotoRenderer {
    static func render(photo: UIImage, filter: MirrorFilter, date: Date, score: Int?, streak: Int) -> UIImage {
        guard filter != .clean, photo.size.width > 0 else { return photo }

        let designWidth: CGFloat = 390
        let designHeight = designWidth * photo.size.height / photo.size.width
        let content = ZStack {
            Image(uiImage: photo)
                .resizable()
                .scaledToFill()
            MirrorOverlay(filter: filter, date: date, score: score, streak: streak)
        }
        .frame(width: designWidth, height: designHeight)
        .clipped()
        .environment(\.colorScheme, .dark)

        let renderer = ImageRenderer(content: content)
        renderer.scale = photo.size.width * photo.scale / designWidth
        return renderer.uiImage ?? photo
    }
}
