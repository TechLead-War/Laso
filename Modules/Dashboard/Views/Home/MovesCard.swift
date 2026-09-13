import SwiftUI

/// The two things to do today: one for the day, one for the night. Each has
/// a reminder and a way to say it happened. The life-context affordance sits
/// under the moves because a context is what overrides them.
struct MovesCard<Context: View>: View {
    let day: DailyBrief.Move
    let night: DailyBrief.Move?
    let onDone: (DailyMoveLog.MoveKind) -> Void
    let onRemind: (DailyMoveLog.MoveKind) -> Void
    @ViewBuilder let lifeContext: () -> Context


    var body: some View {
        VStack(alignment: .leading, spacing: DS.space4) {
            block(day, eyebrow: Copy.DailyBrief.Day.label, doneID: "home.action.markDone", remindID: "home.action.remind")

            if let night {
                Divider().overlay(AppColour.borderLow)
                block(night, eyebrow: Copy.DailyBrief.Night.label, doneID: "home.action.nightDone", remindID: "home.action.nightRemind")
            }

            lifeContext()
        }
        .padding(DS.cardPadding)
        .cardStyle()
        // A container, so the card's identifier does not overwrite the ones on
        // the Done and Remind buttons inside it.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.todaysActionCard")
        // On the card, not a button: marking done swaps the button row out for
        // the confirmation row, which would drop the haptic with it.
        .sensoryFeedback(.success, trigger: day.isDone || (night?.isDone ?? false)) { _, new in new }
    }

    private func block(_ move: DailyBrief.Move, eyebrow: String, doneID: String, remindID: String) -> some View {
        VStack(alignment: .leading, spacing: DS.space2) {
            Text(eyebrow)
                .font(DS.Typography.captionSemibold)
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(move.kind == .day ? AppColour.scoreGood : AppColour.info)

            if move.isDone {
                doneRow(move)
            } else {
                Text(move.title)
                    .font(DS.Typography.title3)
                    .foregroundStyle(AppColour.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(move.reason)
                    .font(DS.Typography.footnote)
                    .foregroundStyle(AppColour.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: DS.space2) {
                    remindButton(move, id: remindID)
                    if move.kind == .day {
                        doneButton(Copy.DailyBrief.Day.done, move: move, id: doneID)
                    } else if move.canMarkDoneNow {
                        doneButton(Copy.DailyBrief.Night.inBedNow, move: move, id: doneID)
                    }
                }
                .padding(.top, DS.space1)
            }
        }
    }

    /// The collapsed confirmation after Done. One row, no buttons: the loop's
    /// next beat is tomorrow's verdict, not more chrome today.
    private func doneRow(_ move: DailyBrief.Move) -> some View {
        HStack(spacing: DS.space2 + 2) {
            Image(systemName: "checkmark.circle.fill")
                .font(DS.Typography.bodySemibold)
                .foregroundStyle(AppColour.success)
            VStack(alignment: .leading, spacing: 2) {
                Text(move.title)
                    .font(DS.Typography.subheadlineSemibold)
                    .foregroundStyle(AppColour.textPrimary)
                    .lineLimit(1)
                Text(Copy.Home.nextUpDoneLogged)
                    .font(DS.Typography.caption)
                    .foregroundStyle(AppColour.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home.action.doneLogged")
    }

    private func doneButton(_ label: String, move: DailyBrief.Move, id: String) -> some View {
        Button {
            onDone(move.kind)
        } label: {
            HStack(spacing: DS.space2 - 1) {
                Image(systemName: "checkmark")
                    .font(DS.Typography.captionSemibold)
                Text(label)
                    .font(DS.Typography.subheadlineSemibold)
            }
            .foregroundStyle(AppColour.scoreGood)
            .frame(maxWidth: .infinity)
            .padding(.vertical, MovesCardMetrics.pillVertical)
            .background(AppColour.scoreGood.opacity(DS.badgeBg), in: RoundedRectangle(cornerRadius: MovesCardMetrics.pillRadius))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }

    private func remindButton(_ move: DailyBrief.Move, id: String) -> some View {
        Button {
            onRemind(move.kind)
        } label: {
            HStack(spacing: DS.space2 - 1) {
                Image(systemName: move.reminderFire == nil ? "clock" : "bell.fill")
                    .font(DS.Typography.captionSemibold)
                Text(move.reminderLabel)
                    .font(DS.Typography.subheadlineSemibold)
                    .lineLimit(1)
            }
            .foregroundStyle(AppColour.textSecondary)
            .padding(.horizontal, DS.space3 + 2)
            .padding(.vertical, MovesCardMetrics.pillVertical)
            .background(AppColour.surfaceSubtle, in: RoundedRectangle(cornerRadius: MovesCardMetrics.pillRadius))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }
}

/// Generic types cannot hold static stored properties, so the pill metrics
/// live beside the card instead of on it.
private enum MovesCardMetrics {
    static let pillRadius: CGFloat = 13
    static let pillVertical: CGFloat = 11
}
