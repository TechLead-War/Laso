import SwiftUI

/// Today's active energy across the day. Every other number on Home is a daily
/// total, so this is the only place that answers "when did it actually happen".
///
/// Built to read as a trace rather than a bar chart, which is the whole reason
/// Apple's day chart works: hairline ticks at 15-minute resolution, a dotted
/// baseline that runs the full width so a quiet stretch still reads as measured,
/// faint gridlines for depth, and the peak printed against the top line so the
/// heights mean something. Rounded bars at hourly resolution cannot look like
/// this no matter how they are styled.
///
/// Drawn with plain shapes rather than Swift Charts: fixed ticks with no
/// selection, no animation and hand-placed rules are less machinery this way,
/// and the card sits inside the Home scroll where the cheapest draw wins.
struct IntradayActivityCard: View {
    /// Values in time order across one day, evenly spaced. Zeros are real quiet
    /// stretches, not gaps.
    let buckets: [Double]

    /// The user's 14-day average day in the same bucket layout, drawn faintly
    /// under today's ticks so today reads against the user's own baseline.
    let usualBuckets: [Double]?

    // Scanned once in init rather than per read — the header number, the peak
    // label, the accessibility string and every tick height all ask for these.
    private let total: Double
    private let peak: Double
    /// One vertical scale for both layers — heights are only comparable if a
    /// kcal is the same number of points in each. An averaged usual day almost
    /// never out-peaks a raw single day, so the top rule stays today's peak in
    /// practice.
    private let scalePeak: Double

    init(buckets: [Double], usualBuckets: [Double]? = nil) {
        self.buckets = buckets
        self.usualBuckets = usualBuckets
        self.total = buckets.reduce(0, +)
        self.peak = buckets.max() ?? 0
        self.scalePeak = max(buckets.max() ?? 0, usualBuckets?.max() ?? 0)
    }

    /// ±15% band around the usual cumulative before the day is called ahead or
    /// behind. WHY: fourteen day-samples of a noisy activity series give a wide
    /// usual range; a narrower band would flip the verdict on ordinary
    /// day-to-day variation and teach the user to ignore it.
    private static let verdictBand = 0.15

    /// Quarter points of the day. Positions come from the fraction, not a bucket
    /// index, so the labels stay put whatever the resolution.
    private static let axisFractions: [(fraction: Double, label: String)] = [
        (0.0, "12am"), (0.25, "6am"), (0.5, "12pm"), (0.75, "6pm")
    ]

    private static let plotHeight: CGFloat = 78
    private static let dash = StrokeStyle(lineWidth: 1, dash: [1, 3])

    var body: some View {
        VStack(alignment: .leading, spacing: DS.space1) {
            Text(Copy.Home.intradayTitle)
                .font(DS.Typography.subheadline)
                .foregroundStyle(AppColour.textSecondary)

            // Number big, unit small beside it, the way a reading is actually read.
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(Int(total.rounded()))")
                    .font(DS.Typography.title)
                    .monospacedDigit()
                Text(Copy.Home.intradayUnit)
                    .font(DS.Typography.subheadlineSemibold)
            }
            .foregroundStyle(AppColour.accent)

            if let verdict = verdictText {
                Text(verdict)
                    .font(DS.Typography.caption)
                    .foregroundStyle(AppColour.textSecondary)
            }

            plot
                .padding(.top, DS.space2)

            axis

            if showsUsualOverlay {
                Text(Copy.Home.intradayUsualLegend)
                    .font(DS.Typography.caption2)
                    .foregroundStyle(AppColour.textTertiary)
            }
        }
        .padding(DS.cardPadding)
        .cardStyle()
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("home.intradayActivity")
        .accessibilityLabel(Copy.Home.intradayAccessibility(Int(total.rounded()), peakLabel))
    }

    private var plot: some View {
        ZStack(alignment: .topLeading) {
            gridlines
            ticks
            // The peak, printed against the top rule it corresponds to, so the
            // tallest tick has a number and every other height is readable
            // against it. Suppressed on the rare day the usual overlay sets the
            // scale instead — printing today's peak against a taller rule would
            // mislabel it.
            if peak > 0, peak >= scalePeak {
                Text(Copy.Home.intradayPeak(Int(peak.rounded())))
                    .font(DS.Typography.caption2)
                    .foregroundStyle(AppColour.textTertiary)
                    .monospacedDigit()
                    .offset(y: -4)
            }
        }
        .frame(height: Self.plotHeight)
    }

    private var gridlines: some View {
        VStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { index in
                Path { path in
                    path.move(to: .zero)
                    path.addLine(to: CGPoint(x: 10_000, y: 0))
                }
                .stroke(AppColour.borderLow, style: Self.dash)
                .frame(height: 1)
                if index < 2 { Spacer(minLength: 0) }
            }
        }
        .frame(height: Self.plotHeight, alignment: .top)
        .clipped()
    }

    private var ticks: some View {
        ZStack(alignment: .bottomLeading) {
            // The baseline runs the whole width in the accent colour, so an
            // empty stretch reads as "measured, nothing here" rather than as
            // a hole in the chart. This single line is most of why the
            // reference picture feels finished.
            BaselineShape()
                .stroke(AppColour.accent.opacity(0.55), style: Self.dash)

            // The usual-day trace sits under today's so today always wins the
            // pixel where they overlap. Same single-Path draw as today's layer.
            if showsUsualOverlay, let usual = usualBuckets {
                TickShape(buckets: usual, peak: scalePeak)
                    .fill(AppColour.accent.opacity(Self.usualOverlayOpacity))
            }

            // One path for all 96 ticks. They never overlap and share one solid
            // colour, so a single fill draws exactly what 96 Rectangles did
            // without 96 view identities and layout entries.
            TickShape(buckets: buckets, peak: scalePeak)
                .fill(AppColour.accent)
        }
    }

    /// Faint enough to read as context under today's solid ticks, strong
    /// enough to survive both colour schemes.
    private static let usualOverlayOpacity = 0.22

    private var showsUsualOverlay: Bool {
        usualBuckets?.contains { $0 > 0 } ?? false
    }

    /// Today's cumulative burn up to the current bucket against the usual
    /// cumulative to the same time of day. Nil until both series exist and the
    /// usual day has recorded anything by this hour.
    private var verdictText: String? {
        guard showsUsualOverlay, let usual = usualBuckets, !buckets.isEmpty else { return nil }
        let now = Date()
        let dayStart = Date.cal.startOfDay(for: now)
        guard let dayEnd = Date.cal.date(byAdding: .day, value: 1, to: dayStart) else { return nil }
        // Fraction of the day, not a bucket index: the two arrays can disagree
        // on count on a DST day, so each maps the fraction into its own layout.
        let fraction = now.timeIntervalSince(dayStart) / dayEnd.timeIntervalSince(dayStart)
        let todaySum = cumulative(of: buckets, upTo: fraction)
        let usualSum = cumulative(of: usual, upTo: fraction)
        guard usualSum > 0 else { return nil }
        if todaySum >= usualSum * (1 + Self.verdictBand) { return Copy.Home.intradayVerdictAhead }
        if todaySum <= usualSum * (1 - Self.verdictBand) { return Copy.Home.intradayVerdictBehind }
        return Copy.Home.intradayVerdictUsual
    }

    private func cumulative(of series: [Double], upTo fraction: Double) -> Double {
        let index = min(series.count - 1, max(0, Int(fraction * Double(series.count))))
        return series.prefix(index + 1).reduce(0, +)
    }

    private struct BaselineShape: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            return path
        }
    }

    private struct TickShape: Shape {
        let buckets: [Double]
        let peak: Double

        func path(in rect: CGRect) -> Path {
            var path = Path()
            guard peak > 0, !buckets.isEmpty else { return path }
            let slot = rect.width / CGFloat(buckets.count)
            // Hairline, never wider than its slot, so 96 ticks stay separate.
            let tickWidth = max(1, min(2, slot * 0.5))
            for (index, value) in buckets.enumerated() where value > 0 {
                let height = max(2, rect.height * (value / peak))
                path.addRect(CGRect(
                    x: rect.minX + slot * CGFloat(index),
                    y: rect.maxY - height,
                    width: tickWidth,
                    height: height
                ))
            }
            return path
        }
    }

    private var axis: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                ForEach(Self.axisFractions, id: \.fraction) { tick in
                    Text(tick.label)
                        .font(DS.Typography.caption2)
                        .foregroundStyle(AppColour.textTertiary)
                        .offset(x: proxy.size.width * tick.fraction)
                }
            }
        }
        .frame(height: 14)
    }

    private var peakLabel: String {
        guard let index = buckets.firstIndex(of: peak), peak > 0, !buckets.isEmpty else { return "" }
        let hour = Int(Double(index) / Double(buckets.count) * 24)
        switch hour {
        case 0:     return "12am"
        case 12:    return "12pm"
        case ..<12: return "\(hour)am"
        default:    return "\(hour - 12)pm"
        }
    }
}

#Preview {
    // 96 fifteen-minute buckets: quiet night, a morning burst, an evening session.
    var sample = [Double](repeating: 0, count: 96)
    for index in 28...34 { sample[index] = Double.random(in: 2...9) }
    for index in 44...48 { sample[index] = Double.random(in: 1...4) }
    for index in 66...76 { sample[index] = Double.random(in: 3...14) }
    sample[70] = 21

    // A smoother, lower usual day, the shape a 14-day average actually has.
    var usual = [Double](repeating: 0, count: 96)
    for index in 26...38 { usual[index] = Double.random(in: 1...5) }
    for index in 42...58 { usual[index] = Double.random(in: 0.5...3) }
    for index in 64...80 { usual[index] = Double.random(in: 2...7) }

    return IntradayActivityCard(buckets: sample, usualBuckets: usual)
        .padding()
        .background(AppColour.surfaceSunken)
}
