import SwiftUI

/// The data filters a Daily Mirror photo can carry. The overlay is baked into
/// the saved JPEG, so what the user picks at capture is what every later
/// surface (replay, Explore, share) shows.
enum MirrorFilter: String, CaseIterable, Identifiable {
    case stamp, tint, streak, clean

    var id: String { rawValue }

    var label: String {
        switch self {
        case .stamp:  return Copy.Mirror.filterStamp
        case .tint:   return Copy.Mirror.filterTint
        case .streak: return Copy.Mirror.filterStreak
        case .clean:  return Copy.Mirror.filterClean
        }
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
            case .tint:
                // Straight frame, no corner radius: the saved JPEG is a full
                // bleed rectangle, so a rounded stroke would clip at the edges.
                Rectangle()
                    .strokeBorder(DS.scoreColor(score ?? 0).opacity(0.9), lineWidth: 10)
            case .streak:
                streakBadge
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
                    ZStack {
                        Circle()
                            .stroke(.white.opacity(0.3), lineWidth: 5)
                        Circle()
                            .trim(from: 0, to: Double(score) / 100.0)
                            .stroke(DS.scoreColor(score), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Text("\(score)")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                    }
                    .frame(width: 48, height: 48)
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
