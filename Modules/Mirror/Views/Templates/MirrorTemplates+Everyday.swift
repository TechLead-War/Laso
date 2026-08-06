import SwiftUI

// MARK: - Field Notes

/// The house style. The day's instruments read out along the edges and the
/// photo keeps the middle.
struct MirrorFieldNotes: View {
    let payload: MirrorPayload
    var analysis: MirrorLegibility.Analysis

    /// The bottom rail's own footprint, measured rather than guessed, so the
    /// ladder can decide how much cover the readouts actually need.
    private static let block = CGRect(x: 0, y: 0.76, width: 1, height: 0.24)

    /// One cell of the rail. A value that is missing is never a zero here, it
    /// is simply absent from this array and the row closes over the gap.
    private struct Cell {
        let name: String
        let value: String
        var tint: Color = .white
    }

    private var cells: [Cell] {
        var out: [Cell] = []
        if let score = payload.score {
            out.append(Cell(name: Copy.Mirror.labelReady, value: "\(score)", tint: DS.scoreColor(score)))
        }
        if let hours = payload.sleepHours {
            out.append(Cell(name: Copy.Mirror.labelSleep, value: MirrorFormat.tightDuration(hours: hours)))
        }
        if let hrv = payload.hrv {
            out.append(Cell(name: Copy.Mirror.labelHrv, value: "\(hrv)"))
        }
        if let resting = payload.restingHeartRate {
            out.append(Cell(name: Copy.Mirror.labelResting, value: "\(resting)"))
        }
        return out
    }

    var body: some View {
        let cells = self.cells
        ZStack(alignment: .bottom) {
            // No rail means nothing down there to protect, and a gradient over
            // an empty corner of the photo is just a stain.
            if !cells.isEmpty {
                MirrorScrim(
                    protection: MirrorLegibility.protection(for: Self.block, analysis: analysis, largeType: false),
                    height: 130
                )
            }
            MirrorCorners(inset: 13, arm: 15, opacity: 0.55)
            VStack(spacing: 0) {
                header
                Spacer(minLength: 0)
                if !cells.isEmpty { rail(cells) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 5) {
                MirrorLabel(MirrorFormat.stamp(payload.date), size: 9.5)
                MirrorLabel(MirrorFormat.clock(payload.date), size: 9.5, opacity: 0.55)
            }
            Spacer(minLength: 0)
            MirrorLabel(Copy.Mirror.dayNumber(payload.streak), size: 9.5, opacity: 0.55)
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
    }

    private func rail(_ cells: [Cell]) -> some View {
        VStack(spacing: 11) {
            Rectangle()
                .fill(.white.opacity(0.45))
                .frame(height: 1)
            HStack(spacing: 0) {
                ForEach(cells.indices, id: \.self) { index in
                    if index > 0 { Spacer(minLength: 8) }
                    MirrorReadout(name: cells[index].name,
                                  value: cells[index].value,
                                  tint: cells[index].tint)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 20)
    }
}

// MARK: - The Number

/// One number, big enough to read across a room.
struct MirrorNumber: View {
    let payload: MirrorPayload
    var analysis: MirrorLegibility.Analysis

    private static let block = CGRect(x: 0, y: 0.62, width: 1, height: 0.38)

    var body: some View {
        if let score = payload.score {
            ZStack(alignment: .bottom) {
                MirrorScrim(
                    protection: MirrorLegibility.protection(for: Self.block, analysis: analysis, largeType: true),
                    height: 250
                )
                VStack(alignment: .leading, spacing: 0) {
                    MirrorLabel(MirrorFormat.stamp(payload.date), size: 9.5)
                        .padding(.leading, 18)
                        .padding(.top, 18)
                    Spacer(minLength: 0)
                    numeral(score)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            EmptyView()
        }
    }

    private func numeral(_ score: Int) -> some View {
        HStack(alignment: .lastTextBaseline, spacing: 14) {
            Text("\(score)")
                .font(MirrorType.numeral(168, weight: .heavy))
                .tracking(-8)
                .foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 8) {
                Rectangle()
                    .fill(DS.scoreColor(score))
                    .frame(width: 34, height: 3)
                MirrorLabel(Copy.Mirror.labelReady, size: 12, opacity: 1)
                MirrorLabel(DS.scoreLabel(score).uppercased(), size: 12, opacity: 0.6)
            }
        }
        // Inset by 4 rather than the usual 18: the numeral is meant to sit
        // almost off the edge, which is what makes it read as scale.
        .padding(.leading, 4)
        .padding(.bottom, 34)
    }
}

// MARK: - One Word

/// One honest word for the kind of day it was, and no numbers anywhere.
struct MirrorOneWord: View {
    let payload: MirrorPayload

    /// Bands the word table reads. Named here because a bare `34` in a
    /// condition tells nobody which end of the day it describes.
    private static let restCeiling = 34
    private static let strongFloor = 85
    private static let restDebtHours = 5.0
    private static let heavyDebtHours = 3.0

    private static let vignetteInk = Color(red: 0.063, green: 0.063, blue: 0.078)

    /// First match wins, in this order. Every branch below the debt checks
    /// needs a score, so the no data row sits between them.
    private var pick: (word: String, line: String) {
        let debt = payload.debtHours ?? 0
        if let score = payload.score, score < Self.restCeiling {
            return (Copy.Mirror.wordRest, Copy.Mirror.wordRestLine)
        }
        if debt >= Self.restDebtHours {
            return (Copy.Mirror.wordRest, Copy.Mirror.wordRestLine)
        }
        if let hours = payload.sleepHours, hours < 5 {
            return (Copy.Mirror.wordTired, Copy.Mirror.wordTiredLine)
        }
        if debt >= Self.heavyDebtHours {
            return (Copy.Mirror.wordHeavy, Copy.Mirror.wordHeavyLine)
        }
        guard let score = payload.score else {
            return (Copy.Mirror.wordToday, Copy.Mirror.wordTodayLine)
        }
        if score < DS.fairFloor {
            return (Copy.Mirror.wordSlow, Copy.Mirror.wordSlowLine)
        }
        if score < DS.optimalFloor {
            return (Copy.Mirror.wordSteady, Copy.Mirror.wordSteadyLine)
        }
        if score < Self.strongFloor {
            return (Copy.Mirror.wordReady, Copy.Mirror.wordReadyLine)
        }
        return (Copy.Mirror.wordStrong, Copy.Mirror.wordStrongLine)
    }

    var body: some View {
        let pick = self.pick
        ZStack {
            // A vignette instead of the bottom scrim ladder: it darkens the
            // ring the type sits in and leaves the face alone, which a bottom
            // gradient cannot do on a portrait this centred.
            RadialGradient(
                colors: [Self.vignetteInk.opacity(0), Self.vignetteInk.opacity(0.52)],
                center: .init(x: 0.5, y: 0.40),
                startRadius: 130,
                endRadius: 330
            )
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                Text(pick.word)
                    .font(MirrorType.serif(42))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.55), radius: 12)
                // The kit has no body voice: its three fonts are for numerals
                // and instrument markings, and this line is a sentence.
                Text(pick.line)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.72))
                    .shadow(color: .black.opacity(0.55), radius: 8)
                    .padding(.top, 14)
                MirrorLabel(MirrorFormat.stamp(payload.date), size: 9, opacity: 0.45)
                    .padding(.top, 18)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 26)
            .padding(.bottom, 28)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
