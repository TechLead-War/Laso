import SwiftUI

/// Shows the result of yesterday's marked-done action: the action plus how this
/// morning's recovery score moved. This is the payoff that closes the daily
/// loop and gives the user a reason to come back and act again.
struct DailyActionResultCard: View {
    let result: DailyActionResultStore.Result
    let onDismiss: () -> Void

    private var tint: Color {
        switch result.direction {
        case .up:     return AppColour.success
        case .steady: return AppColour.info
        case .down:   return AppColour.warning
        }
    }

    private var resultLine: String {
        switch result.direction {
        case .up:     return Copy.Home.dailyResultUp(delta: result.delta)
        case .steady: return Copy.Home.dailyResultSteady
        case .down:   return Copy.Home.dailyResultDown(delta: abs(result.delta))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(Copy.Home.dailyResultHeader)
                .font(DS.Typography.captionSemibold)
                .tracking(1.2)
                .foregroundStyle(tint)

            HStack(spacing: 12) {
                Image(systemName: result.record.actionIcon)
                    .font(DS.Typography.title3)
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(tint, in: RoundedRectangle(cornerRadius: 10))

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

            Button(action: onDismiss) {
                Text(Copy.Home.dailyResultDismiss)
                    .font(DS.Typography.caption)
                    .foregroundStyle(tint)
            }
            .buttonStyle(.plain)
        }
        .padding(DS.cardPadding)
        .cardStyle(tint: tint)
        .padding(.horizontal, DS.screenPadding)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(Copy.Home.dailyResultHeader). \(result.record.actionTitle). \(resultLine)")
        .accessibilityIdentifier("home.dailyResultCard")
    }
}
