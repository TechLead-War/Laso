import SwiftUI

/// The row of what-is-going-on chips under the greeting. Tapping one turns it on
/// for its own window; tapping again turns it off. An active rest context is a
/// hard constraint on the day's action, so this row sits above the action card
/// rather than buried in settings.
struct LifeContextChipRow: View {
    let store: LifeContextStore

    var body: some View {
        VStack(alignment: .leading, spacing: DS.space2) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.space2) {
                    ForEach(LifeContextStore.Context.allCases, id: \.self) { context in
                        chip(context)
                    }
                }
                .padding(.horizontal, DS.screenPadding)
            }

            // Nothing switches itself off, so the only thing keeping a stale
            // context from suppressing advice for months is asking.
            ForEach(store.needingConfirmation(), id: \.self) { context in
                confirmRow(context)
            }
        }
        .accessibilityIdentifier("home.lifeContextChips")
    }

    private func confirmRow(_ context: LifeContextStore.Context) -> some View {
        HStack(spacing: DS.space2) {
            Text(Copy.Home.contextStillOn(context.displayName.lowercasedFirst))
                .font(DS.Typography.footnote)
                .foregroundStyle(AppColour.textSecondary)

            Spacer(minLength: 8)

            Button(Copy.Home.contextStillYes) {
                AppAnalytics.shared.trackBlockTap(
                    title: "Life Context Confirmed",
                    type: .homeDailyAction,
                    screen: .home,
                    metadata: ["life_context": context.rawValue, "still_on": true]
                )
                store.confirm(context)
            }
            .font(DS.Typography.footnoteMedium)
            .foregroundStyle(AppColour.accent)

            Button(Copy.Home.contextStillNo) {
                AppAnalytics.shared.trackBlockTap(
                    title: "Life Context Confirmed",
                    type: .homeDailyAction,
                    screen: .home,
                    metadata: ["life_context": context.rawValue, "still_on": false]
                )
                store.toggle(context)
            }
            .font(DS.Typography.footnoteMedium)
            .foregroundStyle(AppColour.textSecondary)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, DS.space3)
        .padding(.vertical, DS.space2)
        .background(AppColour.surfaceRaised, in: RoundedRectangle(cornerRadius: DS.Radius.md))
        .padding(.horizontal, DS.screenPadding)
        .accessibilityIdentifier("home.lifeContext.confirm")
    }

    private func chip(_ context: LifeContextStore.Context) -> some View {
        let isOn = store.isActive(context)
        let tint = context.requiresRest ? AppColour.danger : AppColour.accent

        return Button {
            store.toggle(context)
            AppAnalytics.shared.trackBlockTap(
                title: context.rawValue,
                type: .homeDailyAction,
                screen: .home,
                metadata: ["life_context": context.rawValue, "turned_on": !isOn]
            )
        } label: {
            HStack(spacing: 6) {
                Image(systemName: context.systemImage)
                    .font(DS.Typography.caption)
                Text(label(for: context, isOn: isOn))
                    .font(DS.Typography.footnoteMedium)
                    .lineLimit(1)
            }
            .foregroundStyle(isOn ? tint : AppColour.textSecondary)
            .padding(.horizontal, DS.space3)
            .padding(.vertical, DS.space2)
            .background(
                Capsule().fill(isOn ? tint.opacity(DS.badgeBg) : AppColour.surfaceRaised)
            )
            .overlay(
                Capsule().strokeBorder(isOn ? tint.opacity(0.45) : AppColour.borderLow, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label(for: context, isOn: isOn))
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
        .accessibilityHint(Copy.Home.contextAddHint)
    }

    /// An active chip shows the day it was switched on. That is a fact we know;
    /// an end date would be a guess about how long the person stays injured.
    private func label(for context: LifeContextStore.Context, isOn: Bool) -> String {
        guard isOn, let start = store.startDate(for: context) else { return context.displayName }
        return Copy.Home.contextSince(context.displayName, start.formatted(.dateTime.day().month(.abbreviated)))
    }
}
