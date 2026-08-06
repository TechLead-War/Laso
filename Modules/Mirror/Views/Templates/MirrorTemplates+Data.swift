import SwiftUI

/// The two literals the data templates are allowed to introduce: deep sleep and
/// a body running older than its years. Kept here so the same cyan cannot drift
/// between The Night and Body Age.
private enum MirrorDataTint {
    static let deep = Color(red: 0.133, green: 0.827, blue: 0.933)
    static let older = Color(red: 0.878, green: 0.361, blue: 0.392)
}

// MARK: - Horizon

/// The last thirty days as landscape, with today standing at the end of it.
struct MirrorHorizon: View {
    let payload: MirrorPayload

    /// The band the drawing is allowed to occupy. Anything taller starts
    /// crossing a centred face. Static because a private stored property would
    /// drop the memberwise init below the access the dispatcher needs.
    private static let bandHeight: CGFloat = 180
    /// Floor of the plot above the band's bottom edge, and the full height of
    /// the 0 to 100 range above that floor.
    private static let floorInset: CGFloat = 50
    private static let plotHeight: CGFloat = 112

    var body: some View {
        if payload.hasHistory, let today = payload.scoreHistory.last {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                band(today: today)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            EmptyView()
        }
    }

    private func band(today: Int) -> some View {
        ZStack(alignment: .bottom) {
            // The only proportional width in this template: the run has to
            // spread across whatever the photo is wide.
            GeometryReader { proxy in
                chart(size: proxy.size, today: today)
            }
            bottomRow(today: today)
        }
        .frame(height: Self.bandHeight)
    }

    private func chart(size: CGSize, today: Int) -> some View {
        let marks = points(in: size, scores: payload.scoreHistory)
        let curve = terrain(marks)
        let tint = DS.scoreColor(today)
        return ZStack(alignment: .topLeading) {
            // This fill is the scrim. It runs to near black at the bottom edge
            // exactly where the numerals sit, so no MirrorScrim is added on top.
            filled(curve, in: size)
                .fill(LinearGradient(
                    colors: [tint.opacity(0.22), .black.opacity(0.78)],
                    startPoint: .top,
                    endPoint: .bottom
                ))
            curve
                .stroke(.white.opacity(0.92), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .shadow(color: .black.opacity(0.45), radius: 3, y: 1)
            if let mean = payload.averageScore {
                averageRule(mean: mean, size: size)
            }
            if let last = marks.last {
                todayMark(at: last, tint: tint, height: size.height, width: size.width)
            }
        }
    }

    private func averageRule(mean: Int, size: CGSize) -> some View {
        let line = y(for: mean, height: size.height)
        return ZStack(alignment: .topLeading) {
            Path { path in
                path.move(to: CGPoint(x: 0, y: line))
                path.addLine(to: CGPoint(x: size.width, y: line))
            }
            .stroke(.white.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4, 5]))
            // Positioned rather than stacked because the label has to track a
            // value that only exists once the chart has been measured.
            MirrorLabel(Copy.Mirror.averageScore(mean), size: 8, opacity: 0.55)
                .frame(width: size.width - 14, height: 12, alignment: .trailing)
                .position(x: (size.width - 14) / 2, y: line - 9)
        }
    }

    private func todayMark(at point: CGPoint, tint: Color, height: CGFloat, width: CGFloat) -> some View {
        // The terrain runs edge to edge, so the last sample sits exactly on the
        // right border and half the marker would be clipped away. The dot is a
        // marker rather than a reading, so pulling it inside costs no accuracy.
        let x = min(point.x, width - 8)
        return ZStack(alignment: .topLeading) {
            Path { path in
                path.move(to: CGPoint(x: x, y: point.y))
                path.addLine(to: CGPoint(x: x, y: height))
            }
            .stroke(tint.opacity(0.6), lineWidth: 2)
            Circle()
                .fill(tint)
                .frame(width: 10, height: 10)
                .overlay(Circle().stroke(.white.opacity(0.7), lineWidth: 1.5))
                .position(x: x, y: point.y)
        }
    }

    private func bottomRow(today: Int) -> some View {
        HStack(alignment: .bottom, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text(String(today))
                    .font(MirrorType.numeral(64, weight: .heavy))
                    .tracking(-2)
                    .foregroundStyle(.white)
                MirrorLabel(Copy.Mirror.labelReady, size: 9)
            }
            Spacer(minLength: 0)
            MirrorLabel(Copy.Mirror.labelThirtyDays, size: 8, opacity: 0.7)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 14)
    }

    /// The band the terrain is drawn across.
    ///
    /// Mapping straight onto 0 to 100 is honest and completely flat: real
    /// readiness lives inside a twenty point range, so a whole month of it drew
    /// as a nearly straight line near the bottom edge. Fitting the plot to the
    /// month's own spread, padded so the best and worst days do not touch the
    /// edges, is what turns it into a shape that differs per person and per day.
    private var window: (low: Double, high: Double) {
        let scores = payload.scoreHistory.map(Double.init)
        guard let low = scores.min(), let high = scores.max(), high > low else { return (0, 100) }
        let padding = max(6, (high - low) * 0.18)
        return (Swift.max(0, low - padding), Swift.min(100, high + padding))
    }

    private func y(for score: Int, height: CGFloat) -> CGFloat {
        let band = window
        let span = Swift.max(band.high - band.low, 1)
        let fraction = (Double(score) - band.low) / span
        return height - Self.floorInset - CGFloat(fraction) * Self.plotHeight
    }

    private func points(in size: CGSize, scores: [Int]) -> [CGPoint] {
        guard scores.count > 1 else { return [] }
        let step = size.width / CGFloat(scores.count - 1)
        return scores.enumerated().map { index, score in
            CGPoint(x: CGFloat(index) * step, y: y(for: score, height: size.height))
        }
    }

    /// Catmull Rom through every point, converted to cubic beziers. A straight
    /// polyline reads as a chart; the smoothed one reads as terrain, which is
    /// the whole point of the template.
    private func terrain(_ points: [CGPoint]) -> Path {
        var path = Path()
        guard points.count > 1, let first = points.first else { return path }
        path.move(to: first)
        for index in 0..<(points.count - 1) {
            let p0 = points[max(index - 1, 0)]
            let p1 = points[index]
            let p2 = points[index + 1]
            let p3 = points[min(index + 2, points.count - 1)]
            let c1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6)
            let c2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
            path.addCurve(to: p2, control1: c1, control2: c2)
        }
        return path
    }

    private func filled(_ curve: Path, in size: CGSize) -> Path {
        var area = curve
        area.addLine(to: CGPoint(x: size.width, y: size.height))
        area.addLine(to: CGPoint(x: 0, y: size.height))
        area.closeSubpath()
        return area
    }
}

// MARK: - The Night

/// Last night the way a sleep clinic draws it.
struct MirrorNight: View {
    let payload: MirrorPayload
    var analysis: MirrorLegibility.Analysis

    /// Static rather than stored: a private stored property would drop the
    /// memberwise init below the access the dispatcher needs.
    private static let chartHeight: CGFloat = 96
    private static let inset: CGFloat = 18
    /// Deepest stage index, so the band maths never hardcodes a bare 3.
    private static let deepestLevel = 3

    var body: some View {
        let stages = payload.sleepStages
        let total = stages.reduce(0) { $0 + $1.minutes }
        if payload.hasStages, total > 0 {
            content(stages: stages, total: total)
        } else {
            EmptyView()
        }
    }

    private func content(stages: [MirrorPayload.SleepStage], total: Double) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 0)
            MirrorLabel(Copy.Mirror.labelLastNight, size: 9.5)
                .padding(.bottom, 9)
            // Stage widths are shares of the night, so this one needs the
            // measured width before it can draw anything.
            GeometryReader { proxy in
                hypnogram(stages: stages, total: total, size: proxy.size)
            }
            .frame(height: Self.chartHeight)
            footer(total: total)
                .frame(height: 28)
                .padding(.bottom, 24)
        }
        .padding(.horizontal, Self.inset)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .background(alignment: .bottom) {
            MirrorScrim(
                protection: MirrorLegibility.protection(
                    for: CGRect(x: 0, y: 0.56, width: 1, height: 0.44),
                    analysis: analysis,
                    largeType: false
                ),
                height: 230
            )
        }
    }

    private func hypnogram(stages: [MirrorPayload.SleepStage], total: Double, size: CGSize) -> some View {
        let steps = stepPath(stages: stages, total: total, size: size)
        var area = steps
        area.addLine(to: CGPoint(x: size.width, y: size.height))
        area.addLine(to: CGPoint(x: 0, y: size.height))
        area.closeSubpath()
        return ZStack(alignment: .topLeading) {
            area.fill(.white.opacity(0.13))
            steps.stroke(.white.opacity(0.95), style: StrokeStyle(lineWidth: 1.6, lineJoin: .round))
            deepRuns(stages: stages, total: total, size: size)
                .stroke(MirrorDataTint.deep, style: StrokeStyle(lineWidth: 3.4, lineCap: .round))
        }
    }

    private func stepPath(stages: [MirrorPayload.SleepStage], total: Double, size: CGSize) -> Path {
        var path = Path()
        guard let first = stages.first else { return path }
        var x: CGFloat = 0
        path.move(to: CGPoint(x: 0, y: band(for: first.level, height: size.height)))
        for stage in stages {
            let level = band(for: stage.level, height: size.height)
            path.addLine(to: CGPoint(x: x, y: level))
            x += size.width * CGFloat(stage.minutes / total)
            path.addLine(to: CGPoint(x: x, y: level))
        }
        return path
    }

    private func deepRuns(stages: [MirrorPayload.SleepStage], total: Double, size: CGSize) -> Path {
        var path = Path()
        let level = band(for: Self.deepestLevel, height: size.height)
        var x: CGFloat = 0
        for stage in stages {
            let width = size.width * CGFloat(stage.minutes / total)
            if stage.level == Self.deepestLevel {
                path.move(to: CGPoint(x: x, y: level))
                path.addLine(to: CGPoint(x: x + width, y: level))
            }
            x += width
        }
        return path
    }

    /// Awake at the top, deep at the floor, with 6 of air at each end so the
    /// thick deep stroke is not clipped by the container.
    private func band(for level: Int, height: CGFloat) -> CGFloat {
        let padding: CGFloat = 6
        let usable = height - padding * 2
        let clamped = min(max(level, 0), Self.deepestLevel)
        return padding + usable * CGFloat(clamped) / CGFloat(Self.deepestLevel)
    }

    private func footer(total: Double) -> some View {
        let bed = payload.date.addingTimeInterval(-total * 60)
        return HStack(spacing: 0) {
            MirrorLabel(MirrorFormat.clock(bed), size: 9, opacity: 0.6)
            Spacer(minLength: 0)
            HStack(spacing: 10) {
                if let hours = payload.sleepHours {
                    pair(value: MirrorFormat.duration(hours: hours),
                         name: Copy.Mirror.labelAsleep,
                         tint: .white)
                }
                if let deep = payload.deepMinutes {
                    pair(value: MirrorFormat.minutes(deep),
                         name: Copy.Mirror.labelDeep,
                         tint: MirrorDataTint.deep)
                }
            }
            Spacer(minLength: 0)
            MirrorLabel(MirrorFormat.clock(payload.date), size: 9, opacity: 0.6)
        }
    }

    private func pair(value: String, name: String, tint: Color) -> some View {
        HStack(spacing: 4) {
            Text(value)
                .font(MirrorType.numeral(11))
                .foregroundStyle(tint)
            MirrorLabel(name, size: 8, opacity: 0.7, colour: tint)
        }
    }
}

// MARK: - Body Age

/// The age you are next to the age your body is behaving like, with the gap
/// between them drawn as real distance.
struct MirrorBodyAge: View {
    let payload: MirrorPayload
    var analysis: MirrorLegibility.Analysis

    var body: some View {
        if let delta = payload.ageDelta,
           let chronological = payload.chronologicalAge,
           let vitality = payload.vitalityAge {
            content(delta: delta, chronological: chronological, vitality: vitality)
        } else {
            EmptyView()
        }
    }

    private func content(delta: Int, chronological: Int, vitality: Int) -> some View {
        // Eight years is where the clamp lands, because past that the second
        // numeral runs off the 390 point edge.
        let gap = CGFloat(min(abs(delta), 8) * 8)
        let accent = tint(for: delta)
        return VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 0)
            HStack(alignment: .firstTextBaseline, spacing: gap) {
                column(value: chronological,
                       weight: .semibold,
                       colour: .white.opacity(0.55),
                       name: Copy.Mirror.labelYourAge)
                column(value: vitality,
                       weight: .heavy,
                       colour: accent,
                       name: Copy.Mirror.labelYourBody)
            }
            MirrorLabel(claim(for: delta), size: 9, opacity: 0.88, colour: accent)
                .padding(.top, 10)
        }
        .padding(.horizontal, 30)
        .padding(.bottom, 50)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .background(alignment: .bottom) {
            MirrorScrim(
                protection: MirrorLegibility.protection(
                    for: CGRect(x: 0, y: 0.72, width: 1, height: 0.28),
                    analysis: analysis,
                    largeType: true
                ),
                height: 150
            )
        }
    }

    /// Numeral and its label as one column, so the label stays under its own
    /// number no matter how wide the gap between the two ages opens.
    private func column(value: Int, weight: Font.Weight, colour: Color, name: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // Solid fill, never an outline: outlined numerals disappear against
            // a bright frame, and the 55% white one is the first to go.
            Text(String(value))
                .font(MirrorType.numeral(84, weight: weight))
                .foregroundStyle(colour)
            MirrorLabel(name, size: 8, opacity: 0.8)
        }
    }

    private func tint(for delta: Int) -> Color {
        if delta > 0 { return MirrorDataTint.deep }
        if delta < 0 { return MirrorDataTint.older }
        return .white
    }

    private func claim(for delta: Int) -> String {
        if delta > 0 { return Copy.Mirror.yearsYounger(abs(delta)) }
        if delta < 0 { return Copy.Mirror.yearsOlder(abs(delta)) }
        return Copy.Mirror.sameAsYourAge
    }
}
