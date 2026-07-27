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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.itemSpacing) {
                    scoreHeader
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
                "signals_count": detail.signals.count
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
            Text(Copy.Explore.daySignalsTitle)
                .font(DS.Typography.caption)
                .foregroundStyle(AppColour.textTertiary)
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
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(signal.title)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(AppColour.textPrimary)
                Spacer(minLength: 8)
                Text(signal.valueText)
                    .font(DS.Typography.subheadlineMedium)
                    .foregroundStyle(AppColour.textPrimary)
            }

            if let fraction = signal.fraction {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(AppColour.borderLow)
                        // One neutral tint on purpose: below usual is bad for
                        // HRV and good for resting heart rate, so a good/bad
                        // colour here would be wrong half the time. The bar
                        // shows size of the gap, the line below reads it out.
                        Capsule()
                            .fill(AppColour.accent)
                            .frame(width: max(3, geo.size.width * fraction))
                    }
                }
                .frame(height: 3)
            }

            Text(signal.gapText)
                .font(DS.Typography.caption)
                .foregroundStyle(AppColour.textTertiary)
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
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
