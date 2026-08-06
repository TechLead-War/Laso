import SwiftUI

/// The Sentence. One line about what the body has been doing, in words the app
/// already wrote, with nothing numeric anywhere on the frame.
struct MirrorSentence: View {
    let payload: MirrorPayload

    var body: some View {
        if let sentence = payload.sentence {
            ZStack(alignment: .bottom) {
                // A serif at 21pt is large type, and large type clears its
                // contrast target at a brightness where body copy would fail.
                // That is why this one template can carry a fixed gradient
                // instead of measuring the frame.
                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.85), location: 0),
                        .init(color: .black.opacity(0.45), location: 0.45),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: .bottom,
                    endPoint: .top
                )
                .frame(height: 220)

                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    VStack(alignment: .leading, spacing: 18) {
                        Text(sentence)
                            .font(MirrorType.serif(21))
                            .foregroundStyle(.white)
                            .lineSpacing(4)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)

                        MirrorLabel(
                            MirrorFormat.stamp(payload.date) + " · " + Copy.Mirror.labelPrivate,
                            size: 9,
                            opacity: 0.55
                        )
                        .padding(.bottom, 26)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 24)
                    .padding(.trailing, 38)
                    .padding(.bottom, 56)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            EmptyView()
        }
    }
}

/// The Claim. Not a number about one day, but an honest name for the kind of
/// month it has been.
struct MirrorClaim: View {
    let payload: MirrorPayload
    var analysis: MirrorLegibility.Analysis

    var body: some View {
        if payload.hasHistory {
            ZStack(alignment: .bottom) {
                MirrorScrim(protection: protection, height: 250)

                VStack(spacing: 0) {
                    MirrorLabel(
                        payload.date.formatted(.dateTime.month(.wide).year()).uppercased(),
                        size: 9.5
                    )
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(18)

                    Spacer(minLength: 0)

                    VStack(spacing: 0) {
                        // The two rules do double duty: they frame the claim as
                        // a stated thing, and they give the eye a hard straight
                        // edge to hold on to when the photo behind is busy.
                        rule

                        Text(archetype.title)
                            .font(.system(size: 29, weight: .bold, design: .monospaced))
                            .tracking(4.6)
                            .foregroundStyle(.white)
                            .padding(.top, 15)
                            .padding(.bottom, 13)

                        rule

                        Text(archetype.line)
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.8))
                            .lineSpacing(2)
                            .multilineTextAlignment(.center)
                            .padding(.top, 13)
                    }
                    .padding(.horizontal, 26)
                    .padding(.bottom, 52)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            EmptyView()
        }
    }

    private var rule: some View {
        Rectangle()
            .fill(.white.opacity(0.85))
            .frame(height: 1)
    }

    private var protection: MirrorLegibility.Protection {
        MirrorLegibility.protection(
            for: CGRect(x: 0, y: 0.62, width: 1, height: 0.38),
            analysis: analysis,
            largeType: true
        )
    }

    /// The name for this month, read in order, first match wins. None of these
    /// may claim a direction the last thirty days do not actually show.
    private var archetype: (title: String, line: String) {
        let history = payload.scoreHistory
        let spread = (history.max() ?? 0) - (history.min() ?? 0)
        if spread <= 12 { return (Copy.Mirror.claimSteady, Copy.Mirror.claimSteadyLine) }

        let recent = history.suffix(10)
        let earlier = history.dropLast(10).suffix(20)
        // A history of exactly ten has nothing to compare against, so the only
        // honest reading left is the spread it already failed.
        guard !earlier.isEmpty else { return (Copy.Mirror.claimSwinging, Copy.Mirror.claimSwingingLine) }

        let move = mean(recent) - mean(earlier)
        if move >= 5 { return (Copy.Mirror.claimClimbing, Copy.Mirror.claimClimbingLine) }
        if move <= -5 { return (Copy.Mirror.claimRebuilding, Copy.Mirror.claimRebuildingLine) }
        return (Copy.Mirror.claimSwinging, Copy.Mirror.claimSwingingLine)
    }

    private func mean(_ values: ArraySlice<Int>) -> Double {
        guard !values.isEmpty else { return 0 }
        return Double(values.reduce(0, +)) / Double(values.count)
    }
}

/// Landmark. A plate that only exists on the handful of days worth marking.
struct MirrorLandmark: View {
    let payload: MirrorPayload

    var body: some View {
        if MirrorTemplate.ArchiveFacts.landmarks.contains(payload.streak) {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    Spacer().frame(height: 110)
                    Text(String(payload.streak))
                        .font(MirrorType.numeral(250, weight: .heavy))
                        .tracking(-12)
                        // Deliberately under the contrast a reader needs: this
                        // is texture on the frame, not information to read. The
                        // number is said properly in the plate below.
                        .foregroundStyle(.white.opacity(0.11))
                        // Three and four digit landmarks are wider than the
                        // frame at 250pt, and without these the numeral
                        // silently truncates to "1..." instead of shrinking.
                        .lineLimit(1)
                        .minimumScaleFactor(0.42)
                        .frame(maxWidth: .infinity)
                    Spacer(minLength: 0)
                }

                // No analysis reaches this template, so the plate carries its
                // own fixed floor rather than a measured one.
                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.85), location: 0),
                        .init(color: .black.opacity(0.35), location: 0.55),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: .bottom,
                    endPoint: .top
                )
                .frame(height: 230)

                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    VStack(spacing: 0) {
                        Rectangle()
                            .fill(.white.opacity(0.8))
                            .frame(width: 60, height: 1)
                            .padding(.bottom, 15)

                        MirrorLabel(Copy.Mirror.landmarkTitle(payload.streak), size: 15, opacity: 1)

                        if let supporting {
                            Text(supporting)
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.72))
                                .lineSpacing(2)
                                .multilineTextAlignment(.center)
                                .padding(.top, 12)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 26)
                    .padding(.bottom, 48)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            EmptyView()
        }
    }

    /// Without a first capture date there is no honest way to name one, so the
    /// line goes rather than the date being guessed.
    private var supporting: String? {
        guard let days = payload.daysSinceFirst else { return nil }
        return Copy.Mirror.landmarkLine(MirrorFormat.longDay(payload.date.daysAgo(days)), payload.captureCount)
    }
}
