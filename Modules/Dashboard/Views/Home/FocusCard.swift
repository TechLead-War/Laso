import SwiftUI

/// The current three-week focus: what it is, the numbers it tracks from day 1
/// to today, and how far along it is. Shown on Today and, with the driver
/// line, on Progress, so both screens describe the same commitment.
struct FocusCard: View {
    let focus: DailyBrief.FocusView
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button {
            onTap?()
        } label: {
            VStack(alignment: .leading, spacing: DS.space3) {
                HStack(alignment: .firstTextBaseline, spacing: DS.space2) {
                    Text(focus.title)
                        .font(DS.Typography.bodySemibold)
                        .foregroundStyle(AppColour.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: DS.space2)
                    Text(focus.weekLabel)
                        .font(DS.Typography.captionSemibold)
                        .foregroundStyle(AppColour.textSecondary)
                        .padding(.horizontal, DS.space2)
                        .padding(.vertical, DS.space1)
                        .background(AppColour.surfaceSubtle, in: Capsule())
                }

                HStack(spacing: DS.space2) {
                    ForEach(Array(focus.kpis.enumerated()), id: \.offset) { _, kpi in
                        kpiTile(kpi)
                    }
                }

                if let driverLine = focus.driverLine {
                    Text(driverLine)
                        .font(DS.Typography.footnote)
                        .foregroundStyle(AppColour.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: DS.space2) {
                    Text(Copy.DailyBrief.Focus.day(focus.dayIndex))
                        .font(DS.Typography.caption)
                        .foregroundStyle(AppColour.textTertiary)
                    ProgressBarView(
                        fraction: Double(focus.dayIndex) / Double(max(focus.totalDays, 1)),
                        color: AppColour.accent,
                        trackColor: AppColour.trackNeutral
                    )
                    Text("\(focus.totalDays)")
                        .font(DS.Typography.caption.monospacedDigit())
                        .foregroundStyle(AppColour.textTertiary)
                }
            }
            .padding(DS.cardPadding)
            .cardStyle()
        }
        .buttonStyle(.plain)
        .disabled(onTap == nil)
        .accessibilityIdentifier("home.focusCard")
    }

    private func kpiTile(_ kpi: DailyBrief.FocusView.KPICell) -> some View {
        VStack(alignment: .leading, spacing: DS.space1) {
            // Stacked, not side by side: a clock value like "−2h 20m → −50m"
            // does not fit a third of the card and wrapped mid-number.
            Text(kpi.value)
                .font(DS.Typography.subheadlineMedium.monospacedDigit())
                .foregroundStyle(AppColour.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            if let to = kpi.to {
                Text("→ \(to)")
                    .font(DS.Typography.subheadlineMedium.monospacedDigit())
                    .foregroundStyle(kpi.improved ? AppColour.scoreGood : AppColour.scoreFair)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Text(kpi.label)
                .font(DS.Typography.caption2)
                .foregroundStyle(AppColour.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.space2)
        .background(AppColour.surfaceSubtle, in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
    }
}
