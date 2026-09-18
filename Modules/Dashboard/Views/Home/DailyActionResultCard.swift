import SwiftUI

/// Shows that yesterday's marked-done action was logged, plus the aggregated
/// proof once enough completions exist. The next-morning delta was removed on
/// purpose: DailyActionResultStore declares a ±2 dead band, so quoting a one
/// morning "+2" claimed causation from inside its own noise floor.
struct DailyActionResultCard: View {
    /// Aggregated proof across completions, built by the caller from evaluated
    /// history. `ActionProofSummary` only carries pre-rendered lines, not these
    /// three fields, so the card names exactly what its copy template needs.
    struct Aggregate {
        let times: Int
        let payoff: String
        let weeks: Int
    }

    let result: DailyActionResultStore.Result
    /// nil until at least `minimumCompletionsForAggregate` completions exist.
    let aggregate: Aggregate?
    let onDismiss: () -> Void

    /// Below this many completions an aggregate is one or two data points
    /// dressed as a pattern, so the card states the plain fact instead
    /// (KEEP-KILL fix row: aggregated proof at n>=3, fact only below).
    static let minimumCompletionsForAggregate = 3

    private var resultLine: String {
        if let aggregate {
            return Copy.Home.dailyResultAggregate(aggregate.times, aggregate.payoff, aggregate.weeks)
        }
        return Copy.Home.dailyResultLogged
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(Copy.Home.dailyResultHeader)
                .font(DS.Typography.captionSemibold)
                .tracking(1.2)
                .foregroundStyle(AppColour.info)

            HStack(spacing: 12) {
                Image(systemName: result.record.actionIcon)
                    .font(DS.Typography.title3)
                    .foregroundStyle(AppColour.textOnAccent)
                    .frame(width: 40, height: 40)
                    .background(AppColour.info, in: RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 3) {
                    Text(result.record.actionTitle)
                        .font(DS.Typography.bodySemibold)
                        .foregroundStyle(AppColour.textPrimary)
                        .lineLimit(2)

                    Text(resultLine)
                        .font(DS.Typography.footnote)
                        .foregroundStyle(AppColour.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            Button {
                AppAnalytics.shared.trackBlockTap(
                    title: "Daily Action Result Dismissed",
                    type: .homeDailyAction,
                    screen: .home,
                    metadata: ["source": "daily_action_result", "delta": result.delta]
                )
                onDismiss()
            } label: {
                Text(Copy.Home.dailyResultDismiss)
                    .font(DS.Typography.caption)
                    .foregroundStyle(AppColour.info)
            }
            .buttonStyle(.plain)
        }
        .padding(DS.cardPadding)
        .cardStyle(tint: AppColour.info)
        .padding(.horizontal, DS.screenPadding)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(Copy.Home.dailyResultHeader). \(result.record.actionTitle). \(resultLine)")
        .accessibilityIdentifier("home.dailyResultCard")
    }
}
