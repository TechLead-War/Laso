import SwiftUI
import UIKit

// The three templates that read a second photo out of the archive. Each one
// takes its days from `MirrorArchiveSlice`, which the caller builds once per
// render, so none of them ever touches the store while laying out.

// MARK: - This Week

/// Today's face over the six before it, as a strip along the bottom edge.
struct MirrorThisWeek: View {
    let payload: MirrorPayload
    var archive: MirrorArchiveSlice
    var analysis: MirrorLegibility.Analysis

    /// Fewer than three faces reads as a gap in the archive rather than as a
    /// week, so the template stands down instead of drawing a thin row.
    private var canDraw: Bool { archive.week.count >= 3 }

    private var protection: MirrorLegibility.Protection {
        MirrorLegibility.protection(
            for: CGRect(x: 0, y: 0.70, width: 1, height: 0.30),
            analysis: analysis,
            largeType: false
        )
    }

    var body: some View {
        if canDraw {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                strip
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // The scrim has to sit under the strip, so it goes in the
            // background rather than through `.mirrorScrim`, which overlays.
            .background(alignment: .bottom) {
                MirrorScrim(protection: protection, height: 150)
                    .allowsHitTesting(false)
            }
        } else {
            EmptyView()
        }
    }

    private var strip: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                MirrorLabel(Copy.Mirror.labelThisWeek, size: 9.5)
                Spacer(minLength: 0)
                MirrorLabel(Copy.Mirror.daysOfSeven(archive.week.count, 7), size: 9.5, opacity: 0.55)
            }
            .padding(.bottom, 12)

            HStack(spacing: 5) {
                ForEach(archive.week) { day in
                    cell(day, isToday: day.id == archive.week.last?.id)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 26)
    }

    private func cell(_ day: MirrorArchiveDay, isToday: Bool) -> some View {
        ZStack(alignment: .bottom) {
            if let image = day.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.white.opacity(0.12)
            }
            if let score = day.score {
                DS.scoreColor(score)
                    .frame(height: 3)
            }
        }
        .frame(width: 42, height: 54)
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .overlay {
            if isToday {
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(.white, lineWidth: 1.5)
                    .padding(-1.5)
            }
        }
        .opacity(isToday ? 1 : 0.72)
    }
}

// MARK: - Then and Now

/// The first ever capture taped into the corner of today's.
struct MirrorThenAndNow: View {
    let payload: MirrorPayload
    var archive: MirrorArchiveSlice

    private var higher: Color { Color(red: 0.2, green: 0.769, blue: 0.553) }
    private var lower: Color { Color(red: 0.89, green: 0.706, blue: 0.353) }
    private var ink: Color { Color(red: 0.11, green: 0.11, blue: 0.125) }

    var body: some View {
        // Today's photo stays the photo and the old one is a small print laid on
        // top of it, never a two up composite. That is what keeps the archive
        // holding a real daily capture rather than a collage of two.
        if let first = archive.first {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                HStack(alignment: .bottom, spacing: 16) {
                    // A sheet of paper with no photo on it is an empty box, so a
                    // missing first image drops the print and the rail reflows.
                    if let image = first.image {
                        tapedPrint(image, date: first.date)
                    }
                    rail(first: first)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(alignment: .bottom) {
                LinearGradient(colors: [.clear, .black.opacity(0.72)],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 230)
                    .allowsHitTesting(false)
            }
        } else {
            EmptyView()
        }
    }

    private func tapedPrint(_ image: UIImage, date: Date) -> some View {
        VStack(spacing: 0) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 96, height: 112)
                .clipShape(RoundedRectangle(cornerRadius: 2))
            Text(MirrorFormat.stamp(date))
                .font(MirrorType.label(8.5))
                .tracking(1.1)
                .foregroundStyle(ink)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(4)
        .frame(width: 104, height: 138)
        // The paper carries its own opaque ground, so the old photo can never
        // fight the new one underneath it whatever the light was that day.
        .background(Color.white.opacity(0.94), in: RoundedRectangle(cornerRadius: 3))
        .rotationEffect(.degrees(-3.5))
        .shadow(color: .black.opacity(0.45), radius: 10, y: 4)
    }

    @ViewBuilder
    private func rail(first: MirrorArchiveDay) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            MirrorLabel(Copy.Mirror.labelThen, size: 8.5, opacity: 0.55)
            if let then = first.score, let now = payload.score {
                Text(String(then))
                    .font(MirrorType.numeral(26, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.top, 2)
                MirrorLabel(Copy.Mirror.labelNow, size: 8.5, opacity: 0.85)
                    .padding(.top, 10)
                Text(String(now))
                    .font(MirrorType.numeral(38, weight: .bold))
                    .foregroundStyle(tint(now: now, then: then))
                    .padding(.top, 2)
            } else {
                Text(MirrorFormat.shortDay(first.date))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.top, 2)
                MirrorLabel(Copy.Mirror.labelNow, size: 8.5, opacity: 0.85)
                    .padding(.top, 10)
                Text(MirrorFormat.shortDay(payload.date))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.top, 2)
            }
            if let days = payload.daysSinceFirst {
                Text(Copy.Mirror.daysApart(days))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(.top, 8)
            }
        }
        // A gradient alone does not save this rail on a blown out backlit
        // frame, where the bottom of the photo is brighter than the type.
        .shadow(color: .black.opacity(0.55), radius: 6, y: 1)
    }

    private func tint(now: Int, then: Int) -> Color {
        if now > then { return higher }
        if now < then { return lower }
        return .white
    }
}

// MARK: - Contact Sheet

/// Nine days as a proof sheet with today ringed in grease pencil. This one
/// draws its own photos and replaces the frame entirely, which is why
/// `MirrorOverlay.drawsOwnPhoto` lists it.
struct MirrorContactSheet: View {
    let payload: MirrorPayload
    var archive: MirrorArchiveSlice

    private var stock: Color { Color(red: 0.043, green: 0.043, blue: 0.051) }
    private var greasePencil: Color { Color(red: 0.878, green: 0.361, blue: 0.392) }
    private var columns: [GridItem] { Array(repeating: GridItem(.flexible(), spacing: 6), count: 3) }

    var body: some View {
        // A proof sheet with a hole in it is not a proof sheet, so nine days is
        // the whole requirement.
        if archive.sheet.count >= 9 {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    MirrorLabel(payload.date.formatted(.dateTime.month(.wide).year()).uppercased())
                    Spacer(minLength: 0)
                    MirrorLabel(Copy.Mirror.dayNumber(payload.streak), opacity: 0.5)
                }
                .padding(.horizontal, 18)
                .padding(.top, 24)

                Spacer(minLength: 0)

                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(Array(archive.sheet.enumerated()), id: \.element.id) { index, day in
                        cell(day,
                             number: payload.streak - (archive.sheet.count - 1 - index),
                             isToday: index == archive.sheet.count - 1)
                    }
                }
                .padding(.horizontal, 18)

                Spacer(minLength: 0)

                HStack(spacing: 0) {
                    MirrorLabel(Copy.Mirror.dayNumber(payload.streak), size: 9)
                    Spacer(minLength: 0)
                    MirrorLabel(Copy.Mirror.labelKeptHere, size: 9, opacity: 0.5)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 22)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // No legibility ladder here. The type sits on the stock and on each
            // cell's own gradient, never on the full frame photo, so there is
            // nothing for the analysis to measure.
            .background(stock)
        } else {
            EmptyView()
        }
    }

    private func cell(_ day: MirrorArchiveDay, number: Int, isToday: Bool) -> some View {
        // The aspect goes on a Color rather than on the image, so the cell height
        // comes from the column width instead of from the photo's pixel size.
        Color.clear
            .aspectRatio(112.0 / 128.0, contentMode: .fill)
            .overlay {
                if let image = day.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color.white.opacity(0.06)
                }
            }
            .overlay(alignment: .bottom) {
                LinearGradient(colors: [.black.opacity(0.7), .clear],
                               startPoint: .bottom, endPoint: .top)
                    .frame(height: 20)
            }
            .overlay(alignment: .bottomLeading) {
                caption(number: number, score: day.score)
                    .padding(5)
            }
            .clipShape(RoundedRectangle(cornerRadius: 2))
            .overlay {
                // A photographer rings the keeper straight onto the sheet.
                if isToday {
                    Ellipse()
                        .strokeBorder(greasePencil, lineWidth: 2.5)
                        .rotationEffect(.degrees(-6))
                        .padding(-4)
                }
            }
    }

    @ViewBuilder
    private func caption(number: Int, score: Int?) -> some View {
        HStack(spacing: 4) {
            if number > 0 {
                MirrorLabel(Copy.Mirror.dayNumber(number), size: 7, opacity: 0.8)
            }
            if let score {
                MirrorLabel(String(score), size: 7, opacity: 0.8)
            }
        }
    }
}
