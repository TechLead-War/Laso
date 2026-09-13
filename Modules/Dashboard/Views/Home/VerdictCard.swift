import SwiftUI

/// The morning after: whether yesterday's two moves counted, with the sleep
/// balance before and after when both are known.
struct VerdictCard: View {
    let verdict: DailyBrief.Verdict
    let onDismiss: () -> Void

    private static let checkSize: CGFloat = 22

    var body: some View {
        VStack(alignment: .leading, spacing: DS.space3) {
            summary
                // One element for VoiceOver: the verdict reads as a sentence, not
                // eight fragments. The dismiss button stays its own target.
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("home.dailyResultCard")

            Button(Copy.Home.dailyResultDismiss, action: onDismiss)
                .font(DS.Typography.footnoteMedium)
                .foregroundStyle(AppColour.info)
                .buttonStyle(.plain)
                .accessibilityIdentifier("home.dailyResultCard.dismiss")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.cardPadding)
        .cardStyle(tint: AppColour.info)
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: DS.space3) {
            Text(Copy.DailyBrief.sectionYesterday)
                .font(DS.Typography.captionSemibold)
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(AppColour.info)

            Text(verdict.headline)
                .font(DS.Typography.bodySemibold)
                .foregroundStyle(AppColour.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(Array(verdict.lines.enumerated()), id: \.offset) { _, line in
                HStack(alignment: .top, spacing: DS.space2 + 2) {
                    Image(systemName: line.done ? "checkmark.circle.fill" : "circle")
                        .font(DS.Typography.bodySemibold)
                        .foregroundStyle(line.done ? AppColour.success : AppColour.textTertiary)
                        .frame(width: Self.checkSize, height: Self.checkSize)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(line.title)
                            .font(DS.Typography.subheadlineSemibold)
                            .foregroundStyle(AppColour.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        if !line.detail.isEmpty {
                            Text(line.detail)
                                .font(DS.Typography.caption)
                                .foregroundStyle(AppColour.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            if let before = verdict.balanceBefore, let after = verdict.balanceAfter {
                balanceRow(before: before, after: after)
            }
        }
    }

    /// Two bars on one scale, so a balance that shrank visibly shrinks.
    private func balanceRow(before: Double, after: Double) -> some View {
        let scale = max(before, after, 0.001)
        let yesterday = Date.cal.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        return HStack(spacing: DS.space2) {
            balanceCell(label: yesterday.formatted(.dateTime.weekday(.abbreviated)),
                        fraction: before / scale, value: before, color: AppColour.textTertiary)
            balanceCell(label: Date().formatted(.dateTime.weekday(.abbreviated)),
                        fraction: after / scale, value: after, color: AppColour.info)
        }
        .padding(.top, DS.space1)
    }

    private func balanceCell(label: String, fraction: Double, value: Double, color: Color) -> some View {
        HStack(spacing: DS.space2) {
            Text(label)
                .font(DS.Typography.caption)
                .foregroundStyle(AppColour.textTertiary)
            ProgressBarView(fraction: fraction, color: color, trackColor: AppColour.trackNeutral)
            Text(Copy.DailyBrief.KPI.behind(value.hoursAsClock))
                .font(DS.Typography.captionSemibold.monospacedDigit())
                .foregroundStyle(AppColour.textPrimary)
        }
        .frame(maxWidth: .infinity)
    }
}
