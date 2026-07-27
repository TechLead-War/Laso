import SwiftUI

/// What Apple Health has actually handed over, one row per signal behind the
/// readiness score.
///
/// The card only appears when something is missing. A full read needs no
/// explanation, and a permanent list of green ticks would just be noise on a
/// screen that is meant to be scanned.
struct DataCoverageCard: View {
    let coverage: [DashboardViewModel.SignalCoverage]
    let onOpenSettings: () -> Void

    private var missing: [DashboardViewModel.SignalCoverage] {
        coverage.filter(\.isMissing)
    }

    var body: some View {
        if !missing.isEmpty {
            VStack(alignment: .leading, spacing: DS.space2) {
                Text(Copy.Home.coverageTitle)
                    .font(DS.Typography.captionSemibold)
                    .tracking(1.2)
                    .foregroundStyle(AppColour.textTertiary)

                ForEach(Array(coverage.enumerated()), id: \.element.id) { index, signal in
                    row(signal)
                    if index < coverage.count - 1 {
                        Divider().overlay(AppColour.borderLow.opacity(0.6))
                    }
                }

                Text(Copy.Home.coverageMissingHint(Self.sentenceList(missing.map(\.metric.displayName))))
                    .font(DS.Typography.caption)
                    .foregroundStyle(AppColour.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)

                Button(action: onOpenSettings) {
                    Text(Copy.Home.coverageOpenSettings)
                        .font(DS.Typography.footnoteMedium)
                        .foregroundStyle(AppColour.accent)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("home.coverage.openSettings")
            }
            .padding(DS.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
            .padding(.horizontal, DS.screenPadding)
            .accessibilityIdentifier("home.dataCoverage")
        }
    }

    private func row(_ signal: DashboardViewModel.SignalCoverage) -> some View {
        HStack {
            Text(signal.metric.displayName)
                .font(DS.Typography.subheadline)
                .foregroundStyle(signal.isMissing ? AppColour.textTertiary : AppColour.textPrimary)
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(signal.isMissing
                 ? Copy.Home.coverageNone
                 : Copy.Home.coverageDays(signal.daysWithData, signal.window))
                .font(DS.Typography.footnoteMedium)
                .foregroundStyle(tint(signal))
        }
        .padding(.vertical, 5)
        .accessibilityElement(children: .combine)
    }

    /// Three bands rather than a pass or fail: a signal that reported on two of
    /// fourteen days is technically present but cannot carry a baseline, and the
    /// person needs to see that difference.
    private func tint(_ signal: DashboardViewModel.SignalCoverage) -> Color {
        if signal.isMissing { return AppColour.danger }
        return Double(signal.daysWithData) / Double(signal.window) >= 0.6
            ? AppColour.success
            : AppColour.warning
    }

    private static func sentenceList(_ items: [String]) -> String {
        guard items.count > 1 else { return items.first ?? "" }
        let head = items.dropLast().joined(separator: Copy.Home.scoreListJoiner)
        return head + Copy.Home.scoreListFinalJoiner + (items.last ?? "")
    }
}
