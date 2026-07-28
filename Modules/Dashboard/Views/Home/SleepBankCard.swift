import SwiftUI

/// The running sleep balance, and how many early nights clear it.
///
/// Every other number on Home resets each morning, so nothing could say "this
/// has been building all week". This one accumulates, which is the whole point
/// of showing it: it turns a run of short nights into a single figure the day's
/// action can be argued from.
///
/// It stays off the screen entirely below `SleepDebtTracker.actionableDebtHours`.
/// A balance of eight minutes is not a finding, and a card reading "you are fine"
/// every morning teaches people to skip past it.
struct SleepBankCard: View {
    let debtHours: Double
    let personalBaseline: Double
    let deficits: [SleepDebtTracker.DailyDeficit]
    let nightsRecorded: Int

    private var nightsToClear: Int { SleepDebtTracker.nightsToClear(debtHours: debtHours) }

    private var paybackMinutes: Int { Int(SleepDebtTracker.paybackExtraMinutes) }

    /// A count of nights only reads as a plan while it is short. Past a week it
    /// reads as a sentence, so the line switches to what one night is worth.
    private var paybackText: String {
        if nightsToClear <= 1 { return Copy.Home.sleepBankPaybackOneNight(paybackMinutes) }
        if nightsToClear <= SleepDebtTracker.paybackNightsWorthQuoting {
            return Copy.Home.sleepBankPayback(nightsToClear, paybackMinutes)
        }
        return Copy.Home.sleepBankPaybackPerNight(paybackMinutes)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(Copy.Home.sleepBankTitle)
                .font(DS.Typography.caption2)
                .foregroundStyle(AppColour.textTertiary)

            balanceRow
                .padding(.top, 10)

            Text(Copy.Home.sleepBankAgainst(personalBaseline.hoursAsClock))
                .font(DS.Typography.caption)
                .foregroundStyle(AppColour.textTertiary)
                .padding(.top, 4)

            nightsChart
                .padding(.top, 16)

            axisRow
                .padding(.top, 6)

            paybackRow
                .padding(.top, 14)

            thinWindowRow
        }
        .padding(DS.cardPadding)
        .cardStyle()
        .accessibilityIdentifier("home.sleepBank")
    }

    /// Only when the window is not full. A balance built from nine nights is a
    /// different claim from one built from fourteen, and the card has to say
    /// which it is rather than let the title imply the full two weeks.
    @ViewBuilder
    private var thinWindowRow: some View {
        if nightsRecorded < deficits.count {
            Text(Copy.Home.sleepBankNightsRecorded(nightsRecorded))
                .font(DS.Typography.caption2)
                .foregroundStyle(AppColour.textTertiary)
                .padding(.top, 8)
        }
    }

    private var balanceRow: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(Copy.Home.sleepBankBehind(debtHours.hoursAsClock))
                .font(DS.Typography.title)
                .foregroundStyle(AppColour.warning)
            Spacer(minLength: 8)
            Text(Copy.Home.sleepBankBehindLabel)
                .font(DS.Typography.caption)
                .foregroundStyle(AppColour.warning)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(AppColour.warning.opacity(0.12), in: Capsule())
        }
        .accessibilityElement(children: .combine)
    }

    /// One bar per night, above or below the line. A night that recorded
    /// nothing draws nothing, so an unworn watch cannot look like a night slept
    /// exactly to target.
    private var nightsChart: some View {
        HStack(alignment: .center, spacing: 4) {
            ForEach(deficits, id: \.date) { night in
                VStack(spacing: 0) {
                    barHalf(height: night.deficit < 0 ? magnitude(night) : 0,
                            colour: AppColour.success, alignment: .bottom)
                    Rectangle()
                        .fill(AppColour.chartZeroLine)
                        .frame(height: 1)
                    barHalf(height: night.deficit > 0 ? magnitude(night) : 0,
                            colour: AppColour.warning, alignment: .top)
                }
            }
        }
        .frame(height: Self.chartHeight)
        .accessibilityHidden(true)
    }

    private static let chartHeight: CGFloat = 52
    private static let barWidth: CGFloat = 8

    /// A full-height bar means a night a quarter short of the person's own
    /// usual, roughly two hours for most people.
    ///
    /// Scaling to the worst night in the window instead looked dramatic and
    /// said nothing: a fortnight of near-identical short nights all drew at
    /// full height, so the chart claimed every night was as bad as it gets.
    private static let fullBarDeficitFraction = 0.25

    private func magnitude(_ night: SleepDebtTracker.DailyDeficit) -> CGFloat {
        guard night.hasData, personalBaseline > 0 else { return 0 }
        let half = (Self.chartHeight - 1) / 2
        let reference = personalBaseline * Self.fullBarDeficitFraction
        let fraction = min(1, abs(night.deficit) / reference)
        return max(2, half * CGFloat(fraction))
    }

    private func barHalf(height: CGFloat, colour: Color, alignment: Alignment) -> some View {
        ZStack(alignment: alignment) {
            Color.clear
            if height > 0 {
                Capsule()
                    .fill(colour)
                    .frame(width: Self.barWidth, height: height)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: (Self.chartHeight - 1) / 2)
    }

    private var axisRow: some View {
        HStack {
            Text(Copy.Home.sleepBankFirstNight)
            Spacer(minLength: 8)
            Text(Copy.Home.sleepBankLastNight)
        }
        .font(DS.Typography.caption2)
        .foregroundStyle(AppColour.textTertiary)
        .accessibilityHidden(true)
    }

    private var paybackRow: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "bed.double.fill")
                .font(DS.Typography.footnote)
                .foregroundStyle(AppColour.accent)
            Text(paybackText)
                .font(DS.Typography.footnote)
                .foregroundStyle(AppColour.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(DS.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColour.surfaceSubtle, in: RoundedRectangle(cornerRadius: DS.Radius.md))
        .accessibilityElement(children: .combine)
    }
}
