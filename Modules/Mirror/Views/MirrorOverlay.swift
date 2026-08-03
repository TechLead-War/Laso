import SwiftUI

/// The data filters a Daily Mirror photo can carry. The overlay is baked into
/// the saved JPEG, so what the user picks at capture is what every later
/// surface (replay, Explore, share) shows.
enum MirrorFilter: String, CaseIterable, Identifiable {
    case stamp, pulse, ring, bigScore, glow, streak, journey, banner, dateOnly, clean

    var id: String { rawValue }

    var label: String {
        switch self {
        case .stamp:    return Copy.Mirror.filterStamp
        case .pulse:    return Copy.Mirror.filterPulse
        case .ring:     return Copy.Mirror.filterRing
        case .bigScore: return Copy.Mirror.filterBigScore
        case .glow:     return Copy.Mirror.filterGlow
        case .streak:   return Copy.Mirror.filterStreak
        case .journey:  return Copy.Mirror.filterJourney
        case .banner:   return Copy.Mirror.filterBanner
        case .dateOnly: return Copy.Mirror.filterDateOnly
        case .clean:    return Copy.Mirror.filterClean
        }
    }

    /// Overlays whose whole content is the readiness score. Offering these on a
    /// day with no score would hand the user a chip that draws nothing.
    var requiresScore: Bool {
        switch self {
        case .pulse, .ring, .bigScore, .glow: return true
        case .stamp, .streak, .journey, .banner, .dateOnly, .clean: return false
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
            case .pulse:
                pulseStrip
            case .ring:
                ringBadge
            case .bigScore:
                bigScore
            case .glow:
                glowFrame
            case .streak:
                streakBadge
            case .journey:
                journeyBadge
            case .banner:
                dayBanner
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

    /// A heartbeat trace running along the bottom with the score beside it.
    /// The most literal "health app" frame the archive can wear.
    @ViewBuilder
    private var pulseStrip: some View {
        if let score {
            VStack {
                Spacer()
                HStack(spacing: DS.space3) {
                    ECGTrace()
                        .stroke(DS.scoreColor(score), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                        .frame(height: 36)
                        .shadow(color: DS.scoreColor(score).opacity(0.8), radius: 5)
                    Text("\(score)")
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, DS.space5)
                .padding(.vertical, DS.space4)
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(colors: [.clear, .black.opacity(0.65)], startPoint: .top, endPoint: .bottom)
                )
            }
        }
    }

    /// A soft aura in the score colour breathing in from the edges: the score
    /// as light around the person, no numbers on the photo at all.
    @ViewBuilder
    private var glowFrame: some View {
        if let score {
            ZStack {
                Rectangle()
                    .strokeBorder(DS.scoreColor(score).opacity(0.7), lineWidth: 6)
                    .blur(radius: 4)
                Rectangle()
                    .strokeBorder(DS.scoreColor(score).opacity(0.95), lineWidth: 2.5)
            }
        }
    }

    /// The habit itself as the headline: which day of the run this face is.
    private var journeyBadge: some View {
        VStack {
            Spacer()
            VStack(spacing: 2) {
                Text(Copy.Mirror.filterJourneyDay(streak))
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                Text(date.formatted(.dateTime.day().month(.abbreviated).year()))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.75))
            }
            .padding(.horizontal, DS.space5)
            .padding(.vertical, DS.space3)
            .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: DS.Radius.lg))
            .padding(.bottom, DS.space5)
        }
    }

    /// Quiet diary strip along the bottom edge: the day, and the score when
    /// there is one, on a gradient so any photo stays legible behind it.
    private var dayBanner: some View {
        VStack {
            Spacer()
            HStack(alignment: .firstTextBaseline) {
                Text(date.formatted(.dateTime.weekday(.wide).day().month(.abbreviated)))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                if let score {
                    Text(Copy.Mirror.recoveryScore(score))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(DS.scoreColor(score))
                }
            }
            .padding(.horizontal, DS.space5)
            .padding(.top, DS.space7)
            .padding(.bottom, DS.space5)
            .background(
                LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .top, endPoint: .bottom)
            )
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

/// One classic ECG beat (flat, small bump, sharp spike, recovery dip) repeated
/// across the width. Decorative shape, not a real trace, so the pattern is a
/// fixed polyline in unit space.
private struct ECGTrace: Shape {
    private static let beat: [CGPoint] = [
        CGPoint(x: 0.00, y: 0.5), CGPoint(x: 0.28, y: 0.5),
        CGPoint(x: 0.34, y: 0.38), CGPoint(x: 0.40, y: 0.5),
        CGPoint(x: 0.46, y: 0.5), CGPoint(x: 0.52, y: 0.95),
        CGPoint(x: 0.58, y: 0.05), CGPoint(x: 0.64, y: 0.80),
        CGPoint(x: 0.70, y: 0.5), CGPoint(x: 1.00, y: 0.5)
    ]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let beats = max(1, Int(rect.width / 90))
        let beatWidth = rect.width / CGFloat(beats)
        for index in 0..<beats {
            let originX = rect.minX + CGFloat(index) * beatWidth
            for (pointIndex, point) in Self.beat.enumerated() {
                let at = CGPoint(x: originX + point.x * beatWidth,
                                 y: rect.minY + point.y * rect.height)
                if index == 0 && pointIndex == 0 {
                    path.move(to: at)
                } else {
                    path.addLine(to: at)
                }
            }
        }
        return path
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
