import SwiftUI

/// One past day, explained. Opened by tapping a day in the month calendar.
///
/// Everything here is read back from what was stored on that day: the score and
/// the baselines the scorer used then, the strain it recorded, and the life
/// context the user had switched on. A day with nothing stored says so instead
/// of drawing zeros, because a fabricated reading on a health screen is worse
/// than an empty one.
struct ExploreDaySheet: View {
    let detail: DashboardViewModel.DayDetail

    @Environment(\.dismiss) private var dismiss
    @State private var showFullPhoto = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.itemSpacing) {
                    scoreHeader
                    mirrorPhoto
                    contextRow
                    if !detail.signals.isEmpty {
                        signalsSection
                    }
                    missingRow
                }
                .padding(DS.cardPadding)
            }
            .background(AppColour.surfaceBase)
            .navigationTitle(detail.date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(Copy.Explore.dayClose) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .accessibilityIdentifier("explore.daySheet")
        .onAppear {
            AppAnalytics.shared.trackFeatureOpen(.exploreDaySheet, metadata: [
                "has_score": detail.score != nil,
                "signals_count": detail.signals.count,
                "has_photo": MirrorPhotoStore.shared.hasPhoto(on: detail.date)
            ])
        }
        .onDisappear { AppAnalytics.shared.trackFeatureClose(.exploreDaySheet) }
    }

    @ViewBuilder
    private var scoreHeader: some View {
        if let score = detail.score, let state = detail.state {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("\(score)")
                    .font(DS.Typography.largeTitle)
                    .foregroundStyle(state.color)
                    .contentTransition(.numericText())
                Text(state.plainName)
                    .font(DS.Typography.headline)
                    .foregroundStyle(AppColour.textSecondary)
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Copy.Explore.monthDayScore(score, state.plainName))
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text(Copy.Explore.dayNoScore)
                    .font(DS.Typography.headline)
                    .foregroundStyle(AppColour.textPrimary)
                Text(Copy.Explore.dayNoScoreHint)
                    .font(DS.Typography.footnote)
                    .foregroundStyle(AppColour.textTertiary)
            }
            .accessibilityElement(children: .combine)
        }
    }

    /// The Daily Mirror photo from that day, when one exists, with the template
    /// that day wears drawn over it. The card is a crop; tapping opens the
    /// uncropped photo full screen.
    @ViewBuilder
    private var mirrorPhoto: some View {
        if let frame = MirrorPhotoFrame.forStoredDay(detail.date) {
            Button {
                AppAnalytics.shared.trackBlockTap(
                    title: "Open mirror photo",
                    type: .mirrorPhotoOpened,
                    screen: .exploreDaySheet,
                    metadata: ["source": "explore_day"]
                )
                showFullPhoto = true
            } label: {
                frame
                    .frame(maxWidth: .infinity)
                    .frame(height: 260)
                    .clipShape(RoundedRectangle(cornerRadius: DS.cardRadius))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Copy.Mirror.journalCardDone)
            .fullScreenCover(isPresented: $showFullPhoto) {
                MirrorPhotoViewer(date: detail.date) { showFullPhoto = false }
            }
        }
    }

    /// What the user had told us was going on. A low score reads as explained
    /// rather than as a failure once this line is there.
    @ViewBuilder
    private var contextRow: some View {
        if !detail.contexts.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(detail.contexts, id: \.rawValue) { context in
                    HStack(spacing: 8) {
                        Image(systemName: context.systemImage)
                            .font(DS.Typography.footnote)
                            .foregroundStyle(AppColour.accent)
                        Text(Copy.Explore.dayContext(context.displayName.lowercasedFirst))
                            .font(DS.Typography.footnote)
                            .foregroundStyle(AppColour.textSecondary)
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(DS.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColour.surfaceElevated, in: RoundedRectangle(cornerRadius: DS.Radius.md))
        }
    }

    private var signalsSection: some View {
        VStack(alignment: .leading, spacing: DS.itemSpacing) {
            // The basis of the comparison is stated here once. Repeating it as a
            // sentence under all four readings is what made the card read as a
            // wall of text.
            HStack(alignment: .firstTextBaseline, spacing: DS.space2) {
                Text(Copy.Explore.daySignalsTitle)
                    .font(DS.Typography.captionSemibold)
                    .foregroundStyle(AppColour.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: DS.space2)
                // Never promise a comparison no row can make: a first-week user
                // has no stored baselines at all.
                if detail.signals.contains(where: { $0.usual != nil }) {
                    Text(Copy.Explore.daySignalsQualifier)
                        .font(DS.Typography.caption)
                        .foregroundStyle(AppColour.textQuaternary)
                        .fixedSize()
                }
            }
            .textCase(.uppercase)

            VStack(spacing: 0) {
                ForEach(Array(detail.signals.enumerated()), id: \.element.id) { index, signal in
                    signalRow(signal)
                    if index < detail.signals.count - 1 {
                        Divider().overlay(AppColour.borderLow)
                    }
                }
            }
        }
        .padding(DS.cardPadding)
        .cardStyle()
    }

    private func signalRow(_ signal: DashboardViewModel.DaySignal) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.space3) {
            VStack(alignment: .leading, spacing: DS.space1) {
                Text(signal.title)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(AppColour.textPrimary)
                    .lineLimit(2)
                Text(signal.subText)
                    .font(DS.Typography.caption)
                    .foregroundStyle(AppColour.textTertiary)
            }
            .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: DS.space2)

            HStack(alignment: .firstTextBaseline, spacing: DS.space1) {
                // Neutral, not the category tint: heart rate variability and
                // resting heart rate share one colour and one icon, so tinting
                // made those two rows read as duplicates. The numbers are what
                // tell them apart.
                Text(signal.valueText)
                    .font(DS.Typography.title3)
                    .foregroundStyle(AppColour.textPrimary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                // Direction is a fact, not a verdict: below usual is bad for HRV
                // and good for resting heart rate, so this stays grey both ways.
                if let arrow = Self.arrow(for: signal.usual) {
                    Image(systemName: arrow)
                        .font(DS.Typography.caption2)
                        .foregroundStyle(AppColour.textTertiary)
                }
            }
            .layoutPriority(1)
        }
        .padding(.vertical, DS.space3)
        // The arrow is an Image, so a combined label would drop the direction
        // silently. `gapText` is the sentence that used to carry it on screen.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([signal.title, signal.valueText, signal.gapText].joined(separator: ", "))
    }

    private static func arrow(for usual: DashboardViewModel.DaySignal.Usual?) -> String? {
        switch usual {
        case .above:        return "arrowtriangle.up.fill"
        case .below:        return "arrowtriangle.down.fill"
        case .atUsual, nil: return nil
        }
    }

    /// Names what the day did not record, so a thinner score is visibly thinner
    /// rather than quietly built on less.
    @ViewBuilder
    private var missingRow: some View {
        if !detail.missing.isEmpty {
            Text(Copy.Explore.dayMissing(detail.missing.map(\.displayName).sentenceList))
                .font(DS.Typography.caption)
                .foregroundStyle(AppColour.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
